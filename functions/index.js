const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

initializeApp();

const db = getFirestore();
const SEARCH_ZONE_RADIUS_METERS = 30;
const HINT_INTERVAL_MILLISECONDS = 60 * 1000;

/**
 * Wraps a callable handler so an unexpected crash is logged and returned to
 * the app with its real cause, instead of the opaque "internal" message.
 * Deliberate HttpsErrors pass through unchanged.
 */
function safe(name, handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error(`${name} failed`, error);
      const detail = [error && error.code, error && error.message]
        .filter(Boolean)
        .join(" ");
      throw new HttpsError("internal", `${name} failed: ${detail || String(error)}`);
    }
  };
}

function timestampMillis(value) {
  return value && typeof value.toMillis === "function" ? value.toMillis() : null;
}

function parseCoordinates(value) {
  if (typeof value !== "string") return null;
  const parts = value.split(",");
  if (parts.length !== 2) return null;

  const parsePart = (part) => {
    const match = part
      .replace(/°/g, "")
      .trim()
      .match(/^([+-]?(?:\d+\.?\d*|\.\d+))\s*([NSEW])?$/i);
    if (!match) return null;

    const number = Number(match[1]);
    const direction = (match[2] || "").toUpperCase();
    if (direction === "S" || direction === "W") return -Math.abs(number);
    if (direction === "N" || direction === "E") return Math.abs(number);
    return number;
  };

  const latitude = parsePart(parts[0]);
  const longitude = parsePart(parts[1]);
  if (
    latitude === null ||
    longitude === null ||
    Math.abs(latitude) > 90 ||
    Math.abs(longitude) > 180
  ) {
    return null;
  }
  return { latitude, longitude };
}

function distanceAndBearing(latitude, longitude, targetLatitude, targetLongitude) {
  const toRadians = (degrees) => (degrees * Math.PI) / 180;
  const lat1 = toRadians(latitude);
  const lat2 = toRadians(targetLatitude);
  const deltaLat = lat2 - lat1;
  const deltaLongitude = toRadians(targetLongitude - longitude);
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(deltaLongitude / 2) ** 2;
  const distanceMeters = 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  const y = Math.sin(deltaLongitude) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLongitude);
  const bearingDegrees = (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
  return { distanceMeters, bearingDegrees };
}

exports.updateHunterProximity = onCall({ region: "us-central1" }, safe("updateHunterProximity", async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before updating hunt progress.");
  }

  const { roomCode, latitude, longitude } = request.data || {};
  if (
    typeof roomCode !== "string" ||
    !/^[A-Z0-9]{4,8}$/i.test(roomCode) ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    Math.abs(latitude) > 90 ||
    Math.abs(longitude) > 180
  ) {
    throw new HttpsError("invalid-argument", "A valid room code and GPS position are required.");
  }

  const code = roomCode.toUpperCase();
  const uid = request.auth.uid;
  const huntRef = db.collection("hunts").doc(code);
  const [huntSnapshot, participantSnapshot, targetSnapshot] = await Promise.all([
    huntRef.get(),
    huntRef.collection("participants").doc(uid).get(),
    huntRef.collection("secret").doc("target_coordinates").get(),
  ]);

  if (!huntSnapshot.exists) {
    throw new HttpsError("not-found", "This hunt no longer exists.");
  }
  if (huntSnapshot.get("status") !== "active") {
    throw new HttpsError("failed-precondition", "This hunt is not active.");
  }
  if (!participantSnapshot.exists) {
    throw new HttpsError("permission-denied", "Join this hunt before updating your location.");
  }
  if (!targetSnapshot.exists) {
    throw new HttpsError("failed-precondition", "The hider has not saved a hunt location.");
  }

  const target = parseCoordinates(targetSnapshot.get("locationCoordinates") || "");
  if (!target) {
    throw new HttpsError("failed-precondition", "The saved hunt location is invalid.");
  }

  const { distanceMeters, bearingDegrees } = distanceAndBearing(
    latitude,
    longitude,
    target.latitude,
    target.longitude,
  );
  const isWithinSearchZone = distanceMeters <= SEARCH_ZONE_RADIUS_METERS;
  const participant = participantSnapshot.data();
  const now = Date.now();
  const startedAt = huntSnapshot.get("startedAt");
  const startedAtMillis = timestampMillis(startedAt);
  const hints = huntSnapshot.get("hints");
  const hintTexts =
    targetSnapshot.get("hints") ||
    (Array.isArray(hints) ? hints.map((hint) => hint.text || "") : []);
  const totalHints = Array.isArray(hints) ? Math.min(hints.length, 3) : 3;
  const scheduledHints =
    startedAtMillis === null
      ? 0
      : Math.min(
          totalHints,
          Math.max(
            0,
            Math.floor((now - startedAtMillis) / HINT_INTERVAL_MILLISECONDS),
          ),
        );
  const hintsUnlocked =
    startedAtMillis !== null
      ? Math.max(
          participant.hintsUnlocked || 0,
          scheduledHints,
          isWithinSearchZone ? totalHints : 0,
        )
      : 0;
  const updates = {
    distanceMeters,
    lastActive: Timestamp.now(),
  };
  if (hintsUnlocked > (participant.hintsUnlocked || 0)) {
    updates.hintsUnlocked = hintsUnlocked;
  }
  await participantSnapshot.ref.update(updates);

  const unlockedHintTexts = Array.isArray(hintTexts)
    ? hintTexts.slice(0, hintsUnlocked)
    : [];
  return {
    distanceMeters,
    bearingDegrees,
    isWithinSearchZone,
    startedAtMillis,
    hintsUnlocked,
    unlockedHints: unlockedHintTexts,
  };
}));

exports.getAvailableHints = onCall({ region: "us-central1" }, safe("getAvailableHints", async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to view hunt hints.");
  }
  const { roomCode, hunterId } = request.data || {};
  if (
    typeof roomCode !== "string" ||
    !/^[A-Z0-9]{4,8}$/i.test(roomCode) ||
    hunterId !== request.auth.uid
  ) {
    throw new HttpsError("invalid-argument", "A valid room code is required.");
  }

  const code = roomCode.toUpperCase();
  const huntRef = db.collection("hunts").doc(code);
  const participantRef = huntRef.collection("participants").doc(request.auth.uid);
  const [huntSnapshot, participantSnapshot, targetSnapshot] = await Promise.all([
    huntRef.get(),
    participantRef.get(),
    huntRef.collection("secret").doc("target_coordinates").get(),
  ]);
  if (!huntSnapshot.exists || huntSnapshot.get("status") !== "active") {
    throw new HttpsError("failed-precondition", "This hunt is not active.");
  }
  if (!participantSnapshot.exists) {
    throw new HttpsError("permission-denied", "Join this hunt before requesting hints.");
  }
  if (!targetSnapshot.exists) {
    throw new HttpsError("failed-precondition", "The hunt hints are unavailable.");
  }

  const hints = targetSnapshot.get("hints") || [];
  const startedAtMillis = timestampMillis(huntSnapshot.get("startedAt"));
  const scheduledHints = startedAtMillis === null
    ? 0
    : Math.min(
        3,
        Array.isArray(hints) ? hints.length : 0,
        Math.max(0, Math.floor((Date.now() - startedAtMillis) / HINT_INTERVAL_MILLISECONDS)),
      );
  const hintsUnlocked = Math.max(
    participantSnapshot.get("hintsUnlocked") || 0,
    scheduledHints,
  );
  if (hintsUnlocked > (participantSnapshot.get("hintsUnlocked") || 0)) {
    await participantRef.update({ hintsUnlocked });
  }

  return {
    hintsUnlocked,
    unlockedHints: Array.isArray(hints) ? hints.slice(0, hintsUnlocked) : [],
  };
}));

exports.getCurrentHunts = onCall({ region: "us-central1" }, safe("getCurrentHunts", async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to view your hunts.");
  }

  const uid = request.auth.uid;
  const [ownedHunts, joinedHunts] = await Promise.all([
    db.collection("hunts").where("hiderId", "==", uid).get(),
    db.collectionGroup("participants").where("id", "==", uid).get(),
  ]);
  const hunts = new Map();
  for (const doc of ownedHunts.docs) hunts.set(doc.id, doc);
  for (const membership of joinedHunts.docs) {
    const huntRef = membership.ref.parent.parent;
    if (!huntRef || hunts.has(huntRef.id)) continue;
    const hunt = await huntRef.get();
    if (hunt.exists) hunts.set(hunt.id, hunt);
  }

  return [...hunts.values()].map((doc) => {
    const data = doc.data();
    return {
      roomCode: doc.id,
      name: data.name || "Untitled Hunt",
      difficulty: data.difficulty || "medium",
      reward: data.reward || null,
      referenceImageUrl: data.referenceImageUrl || null,
      status: data.status || "waiting",
      hiderId: data.hiderId || "",
      hiderName: data.hiderName || "",
      createdAtMillis: timestampMillis(data.createdAt) || Date.now(),
      startedAtMillis: timestampMillis(data.startedAt),
      completedAtMillis: timestampMillis(data.completedAt),
      winnerId: data.winnerId || null,
      winnerName: data.winnerName || null,
      winnerRole: data.winnerRole || null,
      hints: Array.isArray(data.hints)
        ? data.hints.map(({ id, label, unlockDistanceMeters }) => ({
            id: id || "",
            label: label || "",
            unlockDistanceMeters: unlockDistanceMeters || 30,
          }))
        : [],
    };
  });
}));