'use strict';

const { randomInt, randomUUID } = require('node:crypto');
const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getStorage } = require('firebase-admin/storage');

initializeApp();

const COUPLE_CODE = /^[A-Z0-9]{6}$/;
const COUPLE_CODE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const INVITATION_TTL_MS = 24 * 60 * 60 * 1000;
const CHAT_BURST_WINDOW_MS = 10 * 1000;
const CHAT_BURST_LIMIT = 12;
const QUICK_MESSAGE_COOLDOWN_MS = 30 * 1000;
const LUDO_FINISH = 52;
const LUDO_START = { A: 36, B: 10 };

const ACTIONS = Object.freeze({
  world_water: { coins: 10, love: 0, energy: 0, plants: 1, mission: 'water_plant', label: 'Regaron plantas 🌱' },
  world_sit: { coins: 0, love: 5, energy: 2, mission: 'sit_together', label: 'Se sentaron juntos ❤️' },
  world_pet: { coins: 0, love: 2, energy: 0, mission: 'pet_pawdo', label: 'Acariciaron a Pawdo 🐶' },
  world_hug: { coins: 0, love: 8, energy: 0, mission: 'hug_partner', label: 'Abrazo de pareja ❤️' },
  interior_sleep: { coins: 0, love: 6, energy: 18, mission: 'sleep_together', label: 'Descansaron juntos 😴' },
  interior_sit: { coins: 4, love: 5, energy: 5, mission: 'sit_together', label: 'Se sentaron juntos en el sofá 🛋️' },
  interior_eat: { coins: 6, love: 4, energy: 10, mission: 'eat_together', label: 'Comieron juntos 🍽️' },
  interior_movie: { coins: 10, love: 14, energy: -4, mission: 'watch_movie', label: 'Vieron una película juntos 🎬' },
  interior_plant: { coins: 4, love: 2, energy: 1, mission: 'water_plant', label: 'Cuidaron una planta interior 🪴' },
  interior_pet: { coins: 2, love: 3, energy: 0, mission: 'pet_pawdo', label: 'Acariciaron a Pawdo dentro de casa 🐶' },
  interior_hug: { coins: 0, love: 8, energy: 0, mission: 'hug_partner', label: 'Abrazo dentro de casa ❤️' },
  room_sleep: { coins: 0, love: 5, energy: 15, mission: 'sleep_together', label: 'Descansaron juntos 😴' },
  room_eat: { coins: 5, love: 4, energy: 8, mission: 'eat_together', label: 'Comieron juntos 🍽️' },
  room_movie: { coins: 8, love: 12, energy: -5, mission: 'watch_movie', label: 'Vieron una película juntos 🎬' },
});

const MISSION_REWARDS = Object.freeze({
  water_plant: { coins: 15, love: 2, energy: 0 },
  pet_pawdo: { coins: 12, love: 3, energy: 0 },
  sit_together: { coins: 15, love: 4, energy: 2 },
  watch_movie: { coins: 20, love: 5, energy: 0 },
  eat_together: { coins: 15, love: 3, energy: 3 },
  sleep_together: { coins: 10, love: 2, energy: 5 },
  hug_partner: { coins: 10, love: 5, energy: 0 },
});

const SHOP_ITEMS = Object.freeze({
  flower_pot_pink: { price: 30, field: 'ownedGardenItems', name: 'Maceta Rosa' },
  flower_bed_large: { price: 60, field: 'ownedGardenItems', name: 'Flores Grandes' },
  flower_box_long: { price: 80, field: 'ownedGardenItems', name: 'Jardinera Larga' },
  bush_flowers: { price: 90, field: 'ownedGardenItems', name: 'Arbusto Floral' },
  tree_flower_small: { price: 120, field: 'ownedGardenItems', name: 'Árbol Pequeño' },
  apple_tree: { price: 180, field: 'ownedGardenItems', name: 'Manzano' },
  tree_big_love: { price: 250, field: 'ownedGardenItems', name: 'Árbol Amor' },
  plant_special_love: { price: 150, field: 'ownedGardenItems', name: 'Planta Especial' },
  table_garden: { price: 220, field: 'ownedGardenItems', name: 'Mesa Romántica' },
  house_basic1: { price: 0, field: 'ownedGardenItems', name: 'Casa Básica' },
  house_basic: { price: 0, field: 'ownedGardenItems', name: 'Casa Básica' },
  house_garden_cozy: { price: 500, field: 'ownedGardenItems', name: 'Casa Jardín Cozy' },
  house_romantic: { price: 1200, field: 'ownedGardenItems', name: 'Casa Romántica' },
  house_blossom: { price: 1600, field: 'ownedGardenItems', name: 'Casa Blossom' },
  house_sunset_cottage: { price: 2000, field: 'ownedGardenItems', name: 'Casa Sunset Cottage' },
  house_modern_love: { price: 2600, field: 'ownedGardenItems', name: 'Casa Modern Love' },
  bed_romantic: { price: 700, field: 'ownedInteriorItems', name: 'Cama Romántica' },
  sofa_romantic: { price: 450, field: 'ownedInteriorItems', name: 'Sofá Romántico' },
  table_romantic: { price: 350, field: 'ownedInteriorItems', name: 'Mesa Romántica' },
  tv_stand_romantic: { price: 400, field: 'ownedInteriorItems', name: 'Mueble TV' },
  plant_inside: { price: 120, field: 'ownedInteriorItems', name: 'Planta Interior' },
  lamp_romantic: { price: 180, field: 'ownedInteriorItems', name: 'Lámpara Romántica' },
  rug_pink: { price: 160, field: 'ownedInteriorItems', name: 'Alfombra Rosa' },
  pet_bed_inside: { price: 250, field: 'ownedInteriorItems', name: 'Cama Pawdo' },
});

// Server-owned placement metadata. Clients may send their current serialized
// layout, but executable asset paths, types and dimensions always come from
// this catalog.
const PLACEMENT_ITEMS = Object.freeze({
  flower_pot_pink: { area: 'garden', type: 'pot', asset: 'garden/flower_pot_pink.png', width: 105, height: 105, label: 'Maceta Rosa' },
  flower_bed_large: { area: 'garden', type: 'flowers', asset: 'garden/flower_bed_large.png', width: 320, height: 125, label: 'Flores Grandes' },
  flower_box_long: { area: 'garden', type: 'flowers', asset: 'garden/flower_box_long.png', width: 355, height: 118, label: 'Jardinera Larga' },
  bush_flowers: { area: 'garden', type: 'bush', asset: 'garden/bush_flowers.png', width: 205, height: 115, label: 'Arbusto Floral' },
  tree_flower_small: { area: 'garden', type: 'tree', asset: 'garden/tree_flower_small.png', width: 155, height: 155, label: 'Árbol Pequeño' },
  apple_tree: { area: 'garden', type: 'tree', asset: 'garden/apple_tree.png', width: 275, height: 275, label: 'Manzano' },
  tree_big_love: { area: 'garden', type: 'tree', asset: 'garden/tree_big_love.png', width: 330, height: 330, label: 'Árbol Amor' },
  plant_special_love: { area: 'garden', type: 'special_plant', asset: 'garden/plant_special_love.png', width: 118, height: 92, label: 'Planta Especial' },
  table_garden: { area: 'garden', type: 'table', asset: 'garden/table_garden.png', width: 205, height: 130, label: 'Mesa Romántica' },
  bed_romantic: { area: 'interior', type: 'bed', asset: 'interior/bed_romantic.png', width: 360, height: 230, label: 'Cama Romántica' },
  sofa_romantic: { area: 'interior', type: 'sofa', asset: 'interior/sofa_romantic.png', width: 390, height: 245, label: 'Sofá Romántico' },
  table_romantic: { area: 'interior', type: 'table', asset: 'interior/table_romantic.png', width: 335, height: 185, label: 'Mesa Romántica' },
  tv_stand_romantic: { area: 'interior', type: 'tv', asset: 'interior/tv_stand_romantic.png', width: 360, height: 230, label: 'Mueble TV' },
  plant_inside: { area: 'interior', type: 'plant', asset: 'interior/plant_inside.png', width: 165, height: 195, label: 'Planta Interior' },
  lamp_romantic: { area: 'interior', type: 'lamp', asset: 'interior/lamp_romantic.png', width: 130, height: 235, label: 'Lámpara Romántica' },
  rug_pink: { area: 'interior', type: 'rug', asset: 'interior/rug_pink.png', width: 430, height: 155, label: 'Alfombra Rosa' },
  pet_bed_inside: { area: 'interior', type: 'pet_bed', asset: 'interior/pet_bed_inside.png', width: 180, height: 120, label: 'Cama Pawdo' },
});

const HOUSE_ITEMS = new Set([
  'house_basic1', 'house_basic', 'house_garden_cozy', 'house_romantic',
  'house_blossom', 'house_sunset_cottage', 'house_modern_love',
]);
const FREE_HOUSES = new Set(['house_basic1', 'house_basic']);

// These IDs are part of the layouts already shipped in the app. They remain
// valid without an inventory entry, but their metadata is still canonicalized
// by the server. A purchased catalog item may additionally have one user-added
// instance.
const STARTER_LAYOUT_ITEMS = Object.freeze({
  garden: Object.freeze({
    tree_big_love_01: { ...PLACEMENT_ITEMS.tree_big_love },
    apple_tree_01: { ...PLACEMENT_ITEMS.apple_tree },
    tree_flower_small_01: { ...PLACEMENT_ITEMS.tree_flower_small },
    bush_flowers_01: { ...PLACEMENT_ITEMS.bush_flowers },
    flower_bed_large_01: { ...PLACEMENT_ITEMS.flower_bed_large },
    flower_box_long_01: { ...PLACEMENT_ITEMS.flower_box_long },
    flower_pot_pink_01: { ...PLACEMENT_ITEMS.flower_pot_pink },
    plant_water_01: { area: 'garden', type: 'plant', asset: 'garden/plant_level_2.png', width: 155, height: 110, label: 'Planta' },
    table_garden_01: { ...PLACEMENT_ITEMS.table_garden },
    plant_special_love_01: { ...PLACEMENT_ITEMS.plant_special_love },
  }),
  interior: Object.freeze({
    bed_01: { ...PLACEMENT_ITEMS.bed_romantic, label: 'Cama' },
    sofa_01: { ...PLACEMENT_ITEMS.sofa_romantic, label: 'Sofá' },
    table_01: { ...PLACEMENT_ITEMS.table_romantic, label: 'Mesa' },
    tv_01: { ...PLACEMENT_ITEMS.tv_stand_romantic, label: 'TV' },
    plant_01: { ...PLACEMENT_ITEMS.plant_inside, label: 'Planta' },
    lamp_01: { ...PLACEMENT_ITEMS.lamp_romantic, label: 'Lámpara' },
    rug_01: { ...PLACEMENT_ITEMS.rug_pink, label: 'Alfombra' },
    pet_bed_01: { ...PLACEMENT_ITEMS.pet_bed_inside, label: 'Cama Pawdo' },
  }),
});

const LAYOUT_LIMIT = 40;
const LAYOUT_BOUNDS = Object.freeze({
  garden: { minX: 120, maxX: 1680, minY: 120, maxY: 820 },
  interior: { minX: 90, maxX: 1710, minY: 160, maxY: 840 },
});

const DAILY_REWARDS = Object.freeze([
  null,
  { coins: 30, love: 1, energy: 2, title: 'Inicio bonito' },
  { coins: 45, love: 2, energy: 2, title: 'Pareja constante' },
  { coins: 60, love: 3, energy: 3, title: 'Cofre dulce' },
  { coins: 80, love: 4, energy: 4, title: 'Racha Pawdo' },
  { coins: 110, love: 5, energy: 5, title: 'Cofre romántico' },
  { coins: 140, love: 6, energy: 6, title: 'Casi premio grande' },
  { coins: 220, love: 10, energy: 10, title: 'Cofre legendario' },
]);

const MINI_GAME_IDS = new Set([
  'couple_questions',
  'challenge_roulette',
  'couple_memory',
  'tic_tac_toe',
  'rock_paper_scissors',
  'movie_guess',
]);

const QUICK_MESSAGES = Object.freeze({
  miss_you: 'Te extraño',
  need_you: 'Te necesito',
  connect: 'Conéctate',
  call_me: 'Llámame',
  love_you: 'Te amo',
  thinking_of_you: 'Estoy pensando en ti',
});

const COUPLE_QUESTIONS = Object.freeze([
  '¿Cuál es tu recuerdo favorito de nosotros?',
  '¿Qué pequeño detalle mío te hace sonreír?',
  '¿A qué lugar te gustaría viajar juntos?',
  '¿Qué canción te recuerda a nuestra relación?',
  '¿Qué meta te emociona cumplir en pareja?',
  '¿Cuál sería nuestra cita perfecta en casa?',
  '¿Qué cualidad admiras más de tu pareja?',
  '¿Qué aventura nueva quieren intentar juntos?',
  '¿Cuál fue el momento en que sentiste más apoyo?',
  '¿Cómo imaginas un día perfecto juntos?',
]);

const COUPLE_CHALLENGES = Object.freeze([
  'Dense un abrazo de al menos veinte segundos.',
  'Dile a tu pareja tres cosas que admiras de ella.',
  'Elijan una canción y bailen juntos.',
  'Preparen una bebida o snack para compartir.',
  'Recreen una foto bonita que tengan juntos.',
  'Planeen una cita sencilla para esta semana.',
  'Cuéntense un recuerdo que todavía les haga reír.',
  'Escriban una nota corta de agradecimiento.',
  'Dejen los teléfonos a un lado durante diez minutos.',
  'Elijan una película que ambos quieran ver.',
]);

const MEMORY_SYMBOLS = Object.freeze(['🐶', '💗', '🌸', '🏠', '🎬', '🍕', '🌙', '🎁']);

const MOVIES = Object.freeze([
  { answer: 'Titanic', emoji: '🚢🧊💙', clue: 'Un viaje inolvidable, un romance y un iceberg.' },
  { answer: 'Coco', emoji: '🎸💀🌼', clue: 'La música conecta a una familia con sus recuerdos.' },
  { answer: 'Up', emoji: '🎈🏠☁️', clue: 'Una casa vuela sostenida por miles de globos.' },
  { answer: 'Frozen', emoji: '❄️👭⛄', clue: 'Dos hermanas descubren que el amor puede salvar un reino.' },
  { answer: 'Ratatouille', emoji: '🐀👨‍🍳🇫🇷', clue: 'Un pequeño chef cocina en París desde un lugar inesperado.' },
  { answer: 'Toy Story', emoji: '🤠🚀🧸', clue: 'Los juguetes viven aventuras cuando nadie los observa.' },
  { answer: 'Shrek', emoji: '🧌🐉👸', clue: 'Un ogro emprende un rescate acompañado por un burro.' },
  { answer: 'Intensamente', emoji: '🧠😊😢', clue: 'Las emociones trabajan juntas dentro de una joven.' },
]);

const MINI_GAME_REWARDS = Object.freeze({
  couple_questions: { coins: 10, love: 2 },
  challenge_roulette: { coins: 8, love: 2 },
  couple_memory: { coins: 25, love: 2 },
  tic_tac_toe: { coins: 20, love: 1 },
  rock_paper_scissors: { coins: 12, love: 1 },
  movie_guess: { coins: 15, love: 1 },
});

const WELLNESS_MOODS = new Set([
  'calm', 'happy', 'sensitive', 'tired', 'sad', 'irritable', 'anxious',
]);
const WELLNESS_FLOWS = new Set(['none', 'spotting', 'light', 'medium', 'heavy']);
const WELLNESS_SYMPTOMS = new Set([
  'cramps', 'headache', 'bloating', 'fatigue', 'backache', 'acne',
  'nausea', 'tenderness', 'insomnia', 'cravings',
]);
const WELLNESS_SHARED_FIELDS = new Set(['mood', 'intensity', 'symptoms']);
const LOCATION_MODES = Object.freeze({
  point: 0,
  '15m': 15 * 60 * 1000,
  '1h': 60 * 60 * 1000,
  '8h': 8 * 60 * 60 * 1000,
  until_stopped: null,
});
const LOCATION_UPDATE_COOLDOWN_MS = 20 * 1000;
const LOCATION_SESSION_START_COOLDOWN_MS = 10 * 1000;
// A foreground-only session must not leave a stale location visible forever
// after an app crash, uninstall or lost connection. Every accepted update
// renews this safety window, without extending the duration chosen by the user.
const LOCATION_STALE_TTL_MS = 20 * 60 * 1000;
const LOCATION_POINT_TTL_MS = 24 * 60 * 60 * 1000;

function requireAuth(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Inicia sesión para continuar.');
  }
  return request.auth.uid;
}

function requireCoupleCode(data) {
  const coupleCode = data?.coupleCode;
  if (typeof coupleCode !== 'string' || !COUPLE_CODE.test(coupleCode)) {
    throw new HttpsError('invalid-argument', 'Código de pareja inválido.');
  }
  return coupleCode;
}

function generateCoupleCode() {
  return Array.from(
    { length: 6 },
    () => COUPLE_CODE_CHARS[randomInt(0, COUPLE_CODE_CHARS.length)],
  ).join('');
}

function storedCoupleCode(value) {
  return typeof value === 'string' && COUPLE_CODE.test(value) ? value : '';
}

function isCompleteCouple(couple) {
  return Boolean(couple?.user1 && couple?.user2);
}

function isActiveCouple(couple) {
  return isCompleteCouple(couple) &&
    (!couple?.status || couple.status === 'paired');
}

function safeMemberProfile(uid, profile) {
  const visibleName = typeof profile?.displayName === 'string'
    ? profile.displayName.trim()
    : '';
  const rawName = visibleName ||
    (typeof profile?.name === 'string' ? profile.name.trim() : '');
  const rawPath = typeof profile?.photoStoragePath === 'string'
    ? profile.photoStoragePath
    : '';
  const summary = {
    uid,
    name: rawName.slice(0, 80) || 'Usuario Pawdo',
  };
  if (rawPath === `profile_photos/${uid}.jpg`) {
    summary.photoStoragePath = rawPath;
  }
  return summary;
}

function isPendingInvitation(couple) {
  return Boolean(
    couple?.user1 &&
    !couple?.user2 &&
    (!couple.status || couple.status === 'pending'),
  );
}

function invitationOwner(couple) {
  return typeof couple?.createdBy === 'string' ? couple.createdBy : couple?.user1;
}

function isPendingInvitationFor(couple, uid) {
  return isPendingInvitation(couple) && invitationOwner(couple) === uid;
}

function invitationExpired(couple, nowMillis) {
  const explicitExpiry = couple?.inviteExpiresAt?.toMillis?.();
  if (Number.isFinite(explicitExpiry)) return explicitExpiry <= nowMillis;
  const legacyCreatedAt = couple?.createdAt?.toMillis?.();
  return Number.isFinite(legacyCreatedAt) &&
    legacyCreatedAt + INVITATION_TTL_MS <= nowMillis;
}

function assertMember(couple, uid) {
  if (!couple || (couple.user1 !== uid && couple.user2 !== uid)) {
    throw new HttpsError('permission-denied', 'No perteneces a esta pareja.');
  }
  if (!isCompleteCouple(couple)) {
    throw new HttpsError('failed-precondition', 'La pareja todavía no está completa.');
  }
}

function assertActiveMember(couple, uid) {
  assertMember(couple, uid);
  if (!isActiveCouple(couple)) {
    throw new HttpsError('failed-precondition', 'La pareja ya no está activa.');
  }
}

function requireMessageId(data) {
  const messageId = data?.messageId;
  if (typeof messageId !== 'string' ||
      !/^[A-Za-z0-9_-]{10,80}$/.test(messageId)) {
    throw new HttpsError('invalid-argument', 'Identificador de mensaje inválido.');
  }
  return messageId;
}

function chatRateUpdate(rate, nowMillis, isQuick) {
  const windowStart = rate?.windowStartedAt?.toMillis?.() || nowMillis;
  const insideWindow = nowMillis - windowStart < CHAT_BURST_WINDOW_MS;
  const count = insideWindow ? number(rate?.count) : 0;
  if (count >= CHAT_BURST_LIMIT) {
    throw new HttpsError(
      'resource-exhausted',
      'Has enviado demasiados mensajes. Espera unos segundos.',
    );
  }
  const lastQuick = rate?.lastQuickAt?.toMillis?.();
  if (isQuick && Number.isFinite(lastQuick) &&
      nowMillis - lastQuick < QUICK_MESSAGE_COOLDOWN_MS) {
    throw new HttpsError(
      'resource-exhausted',
      'Espera 30 segundos antes de enviar otro mensaje rápido.',
    );
  }
  return {
    windowStartedAt: Timestamp.fromMillis(insideWindow ? windowStart : nowMillis),
    count: count + 1,
    lastSentAt: FieldValue.serverTimestamp(),
    ...(isQuick ? { lastQuickAt: FieldValue.serverTimestamp() } : {}),
  };
}

function number(value, fallback = 0) {
  return Number.isFinite(value) ? Math.trunc(value) : fallback;
}

function clamp(value, min = 0, max = 100) {
  return Math.max(min, Math.min(max, value));
}

function limaDateKey(date = new Date()) {
  return new Date(date.getTime() - 5 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function previousDateKey(date = new Date()) {
  return limaDateKey(new Date(date.getTime() - 24 * 60 * 60 * 1000));
}

function requireExpectedRevision(data) {
  const revision = data?.expectedRevision;
  if (!Number.isSafeInteger(revision) || revision < 0) {
    throw new HttpsError('invalid-argument', 'Revisión de diseño inválida.');
  }
  return revision;
}

function layoutCatalogItemId(rawItem, area) {
  if (typeof rawItem.catalogItemId === 'string') {
    const explicit = PLACEMENT_ITEMS[rawItem.catalogItemId];
    if (!explicit || explicit.area !== area) {
      throw new HttpsError('invalid-argument', 'Objeto de catálogo inválido.');
    }
    return rawItem.catalogItemId;
  }

  if (typeof rawItem.id === 'string' &&
      PLACEMENT_ITEMS[rawItem.id]?.area === area) {
    return rawItem.id;
  }

  const suppliedAsset = area === 'garden' ? rawItem.asset : rawItem.assetPath;
  if (typeof suppliedAsset !== 'string') return '';
  const match = Object.entries(PLACEMENT_ITEMS).find(
    ([, item]) => item.area === area && item.asset === suppliedAsset,
  );
  return match?.[0] || '';
}

function normalizeSharedLayout(area, rawLayout, couple) {
  if (area !== 'garden' && area !== 'interior') {
    throw new HttpsError('invalid-argument', 'Área de diseño inválida.');
  }
  if (!Array.isArray(rawLayout) || rawLayout.length > LAYOUT_LIMIT) {
    throw new HttpsError(
      'invalid-argument',
      `El diseño admite como máximo ${LAYOUT_LIMIT} objetos.`,
    );
  }

  const bounds = LAYOUT_BOUNDS[area];
  const starters = STARTER_LAYOUT_ITEMS[area];
  const inventoryField = area === 'garden'
    ? 'ownedGardenItems'
    : 'ownedInteriorItems';
  const owned = new Set(
    Array.isArray(couple[inventoryField]) ? couple[inventoryField] : [],
  );
  const seenIds = new Set();
  const seenCatalogItems = new Set();
  const purchasedFootprints = [];

  return rawLayout.map((rawItem) => {
    if (!rawItem || typeof rawItem !== 'object' || Array.isArray(rawItem)) {
      throw new HttpsError('invalid-argument', 'Objeto de diseño inválido.');
    }
    const id = rawItem.id;
    if (typeof id !== 'string' ||
        !/^[A-Za-z0-9_-]{1,80}$/.test(id) || seenIds.has(id)) {
      throw new HttpsError('invalid-argument', 'Identificador de objeto inválido o duplicado.');
    }
    seenIds.add(id);

    const x = rawItem.x;
    const y = rawItem.y;
    if (!Number.isFinite(x) || !Number.isFinite(y) ||
        x < bounds.minX || x > bounds.maxX ||
        y < bounds.minY || y > bounds.maxY) {
      throw new HttpsError('invalid-argument', 'Coordenadas de objeto inválidas.');
    }

    const starter = starters[id];
    let metadata = starter;
    let catalogItemId = '';
    if (!metadata) {
      catalogItemId = layoutCatalogItemId(rawItem, area);
      metadata = PLACEMENT_ITEMS[catalogItemId];
      if (!metadata) {
        throw new HttpsError('invalid-argument', 'Objeto no reconocido en el diseño.');
      }
      if (!owned.has(catalogItemId)) {
        throw new HttpsError('failed-precondition', 'El objeto no pertenece al inventario compartido.');
      }
      if (seenCatalogItems.has(catalogItemId)) {
        throw new HttpsError('failed-precondition', 'Solo puedes colocar una instancia de cada objeto comprado.');
      }
      seenCatalogItems.add(catalogItemId);

      // Existing starter scenes intentionally contain visually overlapping
      // sprites. Collision enforcement therefore applies only to newly placed
      // inventory items. Rugs are floor layers and do not block furniture.
      if (metadata.type !== 'rug') {
        const footprint = {
          id,
          x,
          y,
          width: metadata.width * 0.55,
          height: metadata.height * 0.35,
        };
        const overlaps = purchasedFootprints.some((placed) =>
          Math.abs(footprint.x - placed.x) <
            (footprint.width + placed.width) / 2 &&
          Math.abs(footprint.y - placed.y) <
            (footprint.height + placed.height) / 2,
        );
        if (overlaps) {
          throw new HttpsError(
            'failed-precondition',
            'Los objetos comprados no pueden superponerse.',
          );
        }
        purchasedFootprints.push(footprint);
      }
    }

    const common = {
      id,
      ...(catalogItemId ? { catalogItemId } : {}),
      type: metadata.type,
      x,
      y,
      width: metadata.width,
      height: metadata.height,
      priority: Math.trunc(y),
    };
    if (area === 'garden') {
      return { ...common, asset: metadata.asset };
    }
    return {
      ...common,
      label: metadata.label,
      assetPath: metadata.asset,
    };
  });
}

function otherSide(side) {
  return side === 'A' ? 'B' : 'A';
}

function tokenList(raw) {
  const values = Array.isArray(raw) ? raw.slice(0, 4).map((v) => number(v, -1)) : [];
  while (values.length < 4) values.push(-1);
  return values;
}

function requireMiniGameId(data) {
  const gameId = data?.gameId;
  if (typeof gameId !== 'string' || !MINI_GAME_IDS.has(gameId)) {
    throw new HttpsError('invalid-argument', 'Juego no permitido.');
  }
  return gameId;
}

function requireWellnessDateKey(data) {
  const dateKey = data?.dateKey;
  if (typeof dateKey !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
    throw new HttpsError('invalid-argument', 'Fecha de bienestar inválida.');
  }
  const value = new Date(`${dateKey}T12:00:00.000Z`);
  if (Number.isNaN(value.getTime()) || value.toISOString().slice(0, 10) !== dateKey) {
    throw new HttpsError('invalid-argument', 'Fecha de bienestar inválida.');
  }
  const earliest = new Date();
  earliest.setUTCFullYear(earliest.getUTCFullYear() - 5);
  const latest = new Date(Date.now() + 24 * 60 * 60 * 1000);
  if (value < earliest || value > latest) {
    throw new HttpsError('invalid-argument', 'La fecha está fuera del rango permitido.');
  }
  return dateKey;
}

function wellnessStringSet(raw, allowed, maxItems) {
  if (!Array.isArray(raw)) return [];
  const values = [...new Set(raw.filter((value) => typeof value === 'string'))];
  if (values.length > maxItems || values.some((value) => !allowed.has(value))) {
    throw new HttpsError('invalid-argument', 'Hay opciones de bienestar no permitidas.');
  }
  return values;
}

function wellnessSharedPayload(entry, sharedFields) {
  const payload = {};
  if (sharedFields.includes('mood')) payload.mood = entry.mood;
  if (sharedFields.includes('intensity')) payload.intensity = entry.flow;
  if (sharedFields.includes('symptoms')) payload.symptoms = entry.symptoms;
  return payload;
}

function shuffle(values) {
  const result = [...values];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const target = randomInt(0, index + 1);
    [result[index], result[target]] = [result[target], result[index]];
  }
  return result;
}

function normalizeAnswer(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function initialMiniGame(gameId, couple) {
  const players = [couple.user1, couple.user2].filter(Boolean);
  const common = {
    gameId,
    players,
    joinedBy: [],
    restartRequestedBy: [],
    abandonedBy: '',
    round: 1,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (gameId === 'couple_questions') {
    const questionIndex = randomInt(0, COUPLE_QUESTIONS.length);
    return {
      publicState: { ...common, phase: 'answering', prompt: COUPLE_QUESTIONS[questionIndex], answeredBy: [], answers: {} },
      privateState: { questionIndex, answers: {} },
    };
  }
  if (gameId === 'challenge_roulette') {
    const challengeIndex = randomInt(0, COUPLE_CHALLENGES.length);
    return {
      publicState: { ...common, phase: 'active', challenge: COUPLE_CHALLENGES[challengeIndex], confirmedBy: [] },
      privateState: { challengeIndex },
    };
  }
  if (gameId === 'couple_memory') {
    const deck = shuffle([...MEMORY_SYMBOLS, ...MEMORY_SYMBOLS]);
    return {
      publicState: { ...common, phase: 'playing', cards: Array(16).fill(''), revealed: [], matched: [], moves: 0, turnUid: couple.user1 },
      privateState: { deck },
    };
  }
  if (gameId === 'tic_tac_toe') {
    return {
      publicState: {
        ...common,
        phase: 'playing',
        board: Array(9).fill(''),
        turnUid: couple.user1,
        winnerUid: '',
        symbols: { [couple.user1]: 'X', [couple.user2]: 'O' },
      },
      privateState: {},
    };
  }
  if (gameId === 'rock_paper_scissors') {
    return {
      publicState: { ...common, phase: 'choosing', submittedBy: [], choices: {}, winnerUid: '' },
      privateState: { choices: {} },
    };
  }
  const movieIndex = randomInt(0, MOVIES.length);
  return {
    publicState: { ...common, phase: 'guessing', emoji: MOVIES[movieIndex].emoji, clue: MOVIES[movieIndex].clue, attempts: 0 },
    privateState: { movieIndex, answer: MOVIES[movieIndex].answer },
  };
}

function nextMiniGameState(gameId, couple, previousRound = 0) {
  const state = initialMiniGame(gameId, couple);
  const round = number(previousRound) + 1;
  state.publicState.round = round;
  const starter = round % 2 === 1 ? couple.user1 : couple.user2;
  if (gameId === 'couple_memory' || gameId === 'tic_tac_toe') {
    state.publicState.turnUid = starter;
  }
  if (gameId === 'tic_tac_toe') {
    const other = starter === couple.user1 ? couple.user2 : couple.user1;
    state.publicState.symbols = { [starter]: 'X', [other]: 'O' };
  }
  return state;
}

function rewardMiniGame(tx, coupleRef, claimRef, claimSnapshot, couple, gameId, uid) {
  if (claimSnapshot.exists) return false;
  const reward = MINI_GAME_REWARDS[gameId];
  if (!reward) return false;
  tx.create(claimRef, {
    gameId,
    claimedBy: uid,
    dateKey: limaDateKey(),
    createdAt: FieldValue.serverTimestamp(),
  });
  tx.update(coupleRef, {
    coins: Math.max(0, number(couple.coins) + reward.coins),
    love: clamp(number(couple.love, 80) + reward.love),
    lastAction: `Recompensa segura de ${gameId}`,
    updatedAt: FieldValue.serverTimestamp(),
  });
  tx.create(coupleRef.collection('economyLedger').doc(`game_${limaDateKey()}_${gameId}`), {
    type: 'game_reward',
    gameId,
    actorUid: uid,
    deltaCoins: reward.coins,
    deltaLove: reward.love,
    balanceAfter: {
      coins: Math.max(0, number(couple.coins) + reward.coins),
      love: clamp(number(couple.love, 80) + reward.love),
    },
    dateKey: limaDateKey(),
    createdAt: FieldValue.serverTimestamp(),
  });
  return true;
}

function ticTacToeWinner(board) {
  const lines = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]];
  for (const [a, b, c] of lines) {
    if (board[a] && board[a] === board[b] && board[a] === board[c]) return board[a];
  }
  return '';
}

function rpsWinner(first, second) {
  if (first === second) return '';
  return (first === 'rock' && second === 'scissors') ||
    (first === 'paper' && second === 'rock') ||
    (first === 'scissors' && second === 'paper') ? 'first' : 'second';
}

async function sendChatMessageHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const messageId = requireMessageId(request.data);
  const quickId = typeof request.data?.quickId === 'string'
    ? request.data.quickId
    : '';
  const isQuick = Boolean(quickId);
  const text = isQuick
    ? QUICK_MESSAGES[quickId]
    : typeof request.data?.text === 'string'
      ? request.data.text.trim()
      : '';
  if (!text || text.length > 2000 || (isQuick && !QUICK_MESSAGES[quickId])) {
    throw new HttpsError('invalid-argument', 'Mensaje inválido.');
  }

  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const messageRef = coupleRef.collection('chat').doc(messageId);
  const rateRef = coupleRef.collection('chatRateLimits').doc(uid);
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, messageSnapshot, rateSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(messageRef), tx.get(rateRef),
    ]);
    const couple = coupleSnapshot.data() || {};
    assertActiveMember(couple, uid);
    if (messageSnapshot.exists) {
      const existing = messageSnapshot.data() || {};
      if (existing.uploadedBy === uid && existing.text === text) {
        return { messageId, sent: true, alreadySent: true };
      }
      throw new HttpsError('already-exists', 'El identificador ya está en uso.');
    }
    tx.set(rateRef, chatRateUpdate(
      rateSnapshot.data() || {},
      Date.now(),
      isQuick,
    ), { merge: true });
    tx.create(messageRef, {
      schemaVersion: 2,
      type: isQuick ? 'quick' : 'text',
      text,
      ...(isQuick ? { quickId } : {}),
      uploadedBy: uid,
      coupleId: coupleCode,
      createdAt: FieldValue.serverTimestamp(),
      timestamp: FieldValue.serverTimestamp(),
    });
    return { messageId, sent: true, alreadySent: false };
  });
}

async function finalizePhotoMessageHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const messageId = requireMessageId(request.data);
  const fileName = request.data?.fileName;
  const storagePath = request.data?.storagePath;
  if (typeof fileName !== 'string' ||
      !/^[A-Za-z0-9_-]{10,160}\.jpg$/.test(fileName) ||
      storagePath !== `couples/${coupleCode}/photos/${fileName}`) {
    throw new HttpsError('invalid-argument', 'Ruta de fotografía inválida.');
  }

  let metadata;
  try {
    [metadata] = await getStorage().bucket().file(storagePath).getMetadata();
  } catch (error) {
    if (error?.code === 404) {
      throw new HttpsError('not-found', 'La fotografía no existe.');
    }
    throw error;
  }
  const sizeBytes = Number(metadata.size);
  const custom = metadata.metadata || {};
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0 ||
      sizeBytes > 1024 * 1024 || metadata.contentType !== 'image/jpeg' ||
      custom.uploadedBy !== uid || custom.coupleCode !== coupleCode) {
    throw new HttpsError('failed-precondition', 'La fotografía no pasó la validación.');
  }

  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const messageRef = coupleRef.collection('chat').doc(messageId);
  const rateRef = coupleRef.collection('chatRateLimits').doc(uid);
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, messageSnapshot, rateSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(messageRef), tx.get(rateRef),
    ]);
    assertActiveMember(coupleSnapshot.data() || {}, uid);
    if (messageSnapshot.exists) {
      const existing = messageSnapshot.data() || {};
      if (existing.uploadedBy === uid && existing.storagePath === storagePath) {
        return { messageId, sent: true, alreadySent: true };
      }
      throw new HttpsError('already-exists', 'El identificador ya está en uso.');
    }
    tx.set(rateRef, chatRateUpdate(
      rateSnapshot.data() || {},
      Date.now(),
      false,
    ), { merge: true });
    tx.create(messageRef, {
      schemaVersion: 2,
      type: 'image',
      storagePath,
      uploadedBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      timestamp: FieldValue.serverTimestamp(),
      coupleCode,
      fileName,
      contentType: 'image/jpeg',
      sizeBytes,
    });
    return { messageId, sent: true, alreadySent: false };
  });
}

async function discardPhotoUploadHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const fileName = request.data?.fileName;
  const storagePath = request.data?.storagePath;
  if (typeof fileName !== 'string' ||
      !/^[A-Za-z0-9_-]{10,160}\.jpg$/.test(fileName) ||
      storagePath !== `couples/${coupleCode}/photos/${fileName}`) {
    throw new HttpsError('invalid-argument', 'Ruta de fotografía inválida.');
  }
  const file = getStorage().bucket().file(storagePath);
  try {
    const [metadata] = await file.getMetadata();
    if (metadata.metadata?.uploadedBy !== uid ||
        metadata.metadata?.coupleCode !== coupleCode) {
      throw new HttpsError('permission-denied', 'No puedes borrar este archivo.');
    }
    await file.delete({ ignoreNotFound: true });
    return { deleted: true };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error?.code === 404) return { deleted: false };
    throw error;
  }
}

async function deleteChatMessageHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const messageId = requireMessageId(request.data);
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const messageRef = coupleRef.collection('chat').doc(messageId);
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, messageSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(messageRef),
    ]);
    assertActiveMember(coupleSnapshot.data() || {}, uid);
    if (!messageSnapshot.exists) return { deleted: false };
    const message = messageSnapshot.data() || {};
    if (message.uploadedBy !== uid) {
      throw new HttpsError('permission-denied', 'Solo puedes borrar tus mensajes.');
    }
    const createdAt = message.createdAt?.toMillis?.();
    if (Number.isFinite(createdAt) && Date.now() - createdAt > 10 * 60 * 1000) {
      throw new HttpsError(
        'failed-precondition',
        'El plazo de 10 minutos para borrar este mensaje terminó.',
      );
    }
    tx.delete(messageRef);
    return { deleted: true };
  });
}

async function markChatReadHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const messageId = requireMessageId(request.data);
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const messageRef = coupleRef.collection('chat').doc(messageId);
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, messageSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(messageRef),
    ]);
    const couple = coupleSnapshot.data() || {};
    assertActiveMember(couple, uid);
    if (!messageSnapshot.exists) {
      throw new HttpsError('not-found', 'El mensaje ya no existe.');
    }
    const message = messageSnapshot.data() || {};
    const readAt = message.createdAt || message.timestamp;
    if (!readAt?.toMillis) {
      throw new HttpsError('failed-precondition', 'El mensaje aún se está enviando.');
    }
    tx.update(coupleRef, {
      chatReadState: {
        ...(couple.chatReadState || {}),
        [uid]: { messageId, readAt, updatedAt: FieldValue.serverTimestamp() },
      },
    });
    return { read: true, messageId };
  });
}

function legalMove(position, dice) {
  if (dice < 1 || dice > 6) return false;
  if (position < 0) return dice === 6;
  return position < LUDO_FINISH;
}

function trackIndex(side, position) {
  return (LUDO_START[side] + position) % 52;
}

async function notifyCoupleActivityHandler(event) {
  const snapshot = event.data;
  if (!snapshot) return;
  const message = snapshot.data() || {};
  const db = getFirestore();
  const coupleSnapshot = await db.doc(`couples/${event.params.coupleCode}`).get();
  if (!coupleSnapshot.exists) return;
  const couple = coupleSnapshot.data();
  if (!isActiveCouple(couple)) return;
  const senderId = message.uploadedBy || message.senderId;
  if (senderId !== couple.user1 && senderId !== couple.user2) return;
  const partnerId = couple.user1 === senderId ? couple.user2 : couple.user1;
  if (!partnerId) return;
  const partnerRef = db.doc(`users/${partnerId}`);
  const [partnerSnapshot, settingsSnapshot, devicesSnapshot] = await Promise.all([
    partnerRef.get(),
    partnerRef.collection('settings').doc('notifications').get(),
    partnerRef.collection('devices').where('enabled', '==', true).limit(20).get(),
  ]);
  const partner = partnerSnapshot.data() || {};
  const settings = settingsSnapshot.data() || {};
  const photo = message.type === 'photo' || message.type === 'image';
  const quick = message.type === 'quick';
  if (settings.chatEnabled === false ||
      (quick && settings.quickMessagesEnabled === false)) return;

  const limaHour = (new Date().getUTCHours() + 19) % 24;
  const quietStart = number(settings.quietStartHour, 22);
  const quietEnd = number(settings.quietEndHour, 8);
  const quiet = quietStart === quietEnd
    ? false
    : quietStart < quietEnd
      ? limaHour >= quietStart && limaHour < quietEnd
      : limaHour >= quietStart || limaHour < quietEnd;
  if (settings.quietHoursEnabled === true && quiet) return;

  const hidden = settings.hideSensitiveContent !== false;
  const title = quick ? 'Pawdo · mensaje rápido' : 'Pawdo';
  const body = photo
    ? 'Tu pareja compartió una foto'
    : quick && !hidden
      ? message.text
      : 'Tienes un nuevo mensaje';
  const deviceDocs = devicesSnapshot.docs.filter((document) => {
    const token = document.data()?.token;
    return typeof token === 'string' && token.length > 20;
  });
  const tokens = [...new Set(deviceDocs.map((document) => document.data().token))];
  if (tokens.length === 0 && typeof partner.fcmToken === 'string') {
    tokens.push(partner.fcmToken);
  }
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      coupleCode: event.params.coupleCode,
      messageId: event.params.messageId,
      type: photo ? 'image' : quick ? 'quick' : 'text',
    },
    android: {
      priority: quick ? 'high' : 'normal',
      collapseKey: `pawdo_chat_${event.params.coupleCode}`,
      notification: {
        channelId: quick ? 'pawdo_quick_messages' : 'pawdo_messages',
        visibility: 'private',
        tag: `pawdo_${event.params.messageId}`,
      },
    },
  });
  const invalidCodes = new Set([
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ]);
  const cleanup = [];
  response.responses.forEach((result, index) => {
    if (result.success || !invalidCodes.has(result.error?.code)) return;
    const token = tokens[index];
    for (const document of deviceDocs) {
      if (document.data().token === token) cleanup.push(document.ref.delete());
    }
    if (partner.fcmToken === token) {
      cleanup.push(partnerRef.update({ fcmToken: FieldValue.delete() }));
    }
  });
  if (cleanup.length > 0) await Promise.allSettled(cleanup);
}

async function cleanupSharedPhotoHandler(event) {
  const data = event.data?.data() || {};
  if (data.type !== 'image' || typeof data.storagePath !== 'string') return;
  const expectedPrefix = `couples/${event.params.coupleCode}/photos/`;
  if (!data.storagePath.startsWith(expectedPrefix) ||
      data.storagePath.slice(expectedPrefix.length).includes('/')) {
    logger.error('Rejected invalid deleted photo path', { path: data.storagePath });
    return;
  }
  try {
    await getStorage().bucket().file(data.storagePath).delete({ ignoreNotFound: true });
  } catch (error) {
    logger.error('Shared photo cleanup failed', { path: data.storagePath, code: error?.code });
    throw error;
  }
}

async function createCoupleCodeHandler(request) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);

  for (let attempt = 0; attempt < 10; attempt += 1) {
    const coupleCode = generateCoupleCode();
    const coupleRef = db.doc(`couples/${coupleCode}`);
    const inviteExpiresAt = Timestamp.fromMillis(Date.now() + INVITATION_TTL_MS);
    const created = await db.runTransaction(async (tx) => {
      const userSnapshot = await tx.get(userRef);
      const user = userSnapshot.data() || {};
      if (!userSnapshot.exists || user.profileCompleted !== true) {
        throw new HttpsError(
          'failed-precondition',
          'Completa tu perfil antes de generar una invitación.',
        );
      }

      const pendingCode = storedCoupleCode(user.pendingCoupleCode);
      const membershipCode = storedCoupleCode(user.coupleCode);
      const referencedCodes = [...new Set([
        coupleCode,
        pendingCode,
        membershipCode,
      ].filter(Boolean))];
      const referencedSnapshots = await Promise.all(
        referencedCodes.map((code) => tx.get(db.doc(`couples/${code}`))),
      );
      const couplesByCode = new Map(
        referencedCodes.map((code, index) => [
          code,
          referencedSnapshots[index].exists
            ? referencedSnapshots[index].data()
            : null,
        ]),
      );

      if (couplesByCode.get(coupleCode)) return false;

      if (membershipCode) {
        const membership = couplesByCode.get(membershipCode);
        const legacyPending = isPendingInvitationFor(membership, uid);
        if (!legacyPending && membership) {
          throw new HttpsError('failed-precondition', 'Ya perteneces a una pareja.');
        }
      }

      // Both the new pending field and the legacy coupleCode may reference an
      // invitation. Delete every owned pending document before creating the
      // replacement so only the newest invitation can remain valid.
      for (const previousCode of new Set([pendingCode, membershipCode])) {
        if (!previousCode || previousCode === coupleCode) continue;
        const previous = couplesByCode.get(previousCode);
        if (isPendingInvitationFor(previous, uid)) {
          tx.delete(db.doc(`couples/${previousCode}`));
        }
      }

      tx.create(coupleRef, {
        code: coupleCode,
        user1: uid,
        user2: null,
        createdBy: uid,
        status: 'pending',
        inviteExpiresAt,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {
        uid,
        email: request.auth.token?.email || user.email || null,
        coupleCode: FieldValue.delete(),
        pendingCoupleCode: coupleCode,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return true;
    });
    if (created) {
      return {
        coupleCode,
        expiresAt: inviteExpiresAt.toMillis(),
      };
    }
  }

  throw new HttpsError('resource-exhausted', 'No se pudo generar un código único. Inténtalo nuevamente.');
}

async function cancelCoupleInvitationHandler(request) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);

  return db.runTransaction(async (tx) => {
    const userSnapshot = await tx.get(userRef);
    if (!userSnapshot.exists) return { cancelled: false };

    const user = userSnapshot.data() || {};
    const pendingCode = storedCoupleCode(user.pendingCoupleCode);
    const membershipCode = storedCoupleCode(user.coupleCode);
    const referencedCodes = [...new Set([
      pendingCode,
      membershipCode,
    ].filter(Boolean))];
    const referencedSnapshots = await Promise.all(
      referencedCodes.map((code) => tx.get(db.doc(`couples/${code}`))),
    );
    const couplesByCode = new Map(
      referencedCodes.map((code, index) => [
        code,
        referencedSnapshots[index].exists
          ? referencedSnapshots[index].data()
          : null,
      ]),
    );

    if (membershipCode) {
      const membership = couplesByCode.get(membershipCode);
      if (membership && !isPendingInvitationFor(membership, uid)) {
        throw new HttpsError(
          'failed-precondition',
          'Ya perteneces a una pareja. No se puede eliminar desde aquí.',
        );
      }
    }

    let cancelled = false;
    for (const code of referencedCodes) {
      const invitation = couplesByCode.get(code);
      if (isPendingInvitationFor(invitation, uid)) {
        tx.delete(db.doc(`couples/${code}`));
        cancelled = true;
      }
    }

    const updates = {
      pendingCoupleCode: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    const legacyMembership = membershipCode
      ? couplesByCode.get(membershipCode)
      : null;
    if (membershipCode &&
        (!legacyMembership || isPendingInvitationFor(legacyMembership, uid))) {
      updates.coupleCode = FieldValue.delete();
    }
    tx.set(userRef, updates, { merge: true });
    return { cancelled };
  });
}

async function joinCoupleHandler(request) {
  const uid = requireAuth(request);
  const rawCode = request.data?.coupleCode;
  const coupleCode = typeof rawCode === 'string' ? rawCode.trim().toUpperCase() : '';
  if (!COUPLE_CODE.test(coupleCode)) {
    throw new HttpsError('invalid-argument', 'El código debe tener 6 letras o números.');
  }

  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, userSnapshot] = await Promise.all([
      tx.get(coupleRef),
      tx.get(userRef),
    ]);
    if (!coupleSnapshot.exists) {
      throw new HttpsError('not-found', 'El código no existe.');
    }
    const couple = coupleSnapshot.data() || {};
    const user = userSnapshot.data() || {};

    if (invitationOwner(couple) === uid) {
      throw new HttpsError('failed-precondition', 'No puedes unirte a tu propio código.');
    }

    if (isCompleteCouple(couple)) {
      if (storedCoupleCode(user.coupleCode) === coupleCode &&
          (couple.user1 === uid || couple.user2 === uid)) {
        return { coupleCode, joined: true, alreadyJoined: true };
      }
      throw new HttpsError('already-exists', 'Ese código ya fue utilizado.');
    }

    if (!isPendingInvitation(couple)) {
      throw new HttpsError('already-exists', 'Ese código ya fue utilizado.');
    }

    if (invitationExpired(couple, Date.now())) {
      throw new HttpsError('deadline-exceeded', 'Código expirado. Genera uno nuevo.');
    }

    if (!userSnapshot.exists || user.profileCompleted !== true) {
      throw new HttpsError(
        'failed-precondition',
        'Completa tu perfil antes de unirte a una pareja.',
      );
    }

    const ownerUid = invitationOwner(couple);
    if (typeof ownerUid !== 'string' || !ownerUid) {
      throw new HttpsError('failed-precondition', 'La invitación no es válida.');
    }
    const ownerRef = db.doc(`users/${ownerUid}`);
    const ownerSnapshot = await tx.get(ownerRef);
    const owner = ownerSnapshot.data() || {};
    if (!ownerSnapshot.exists || owner.profileCompleted !== true) {
      throw new HttpsError(
        'failed-precondition',
        'La invitación no tiene un perfil válido.',
      );
    }

    const userPendingCode = storedCoupleCode(user.pendingCoupleCode);
    const userMembershipCode = storedCoupleCode(user.coupleCode);
    const ownerPendingCode = storedCoupleCode(owner.pendingCoupleCode);
    const ownerMembershipCode = storedCoupleCode(owner.coupleCode);
    const referencedCodes = [...new Set([
      userPendingCode,
      userMembershipCode,
      ownerPendingCode,
      ownerMembershipCode,
    ].filter((code) => code && code !== coupleCode))];
    const referencedSnapshots = await Promise.all(
      referencedCodes.map((code) => tx.get(db.doc(`couples/${code}`))),
    );
    const couplesByCode = new Map([[coupleCode, couple]]);
    referencedCodes.forEach((code, index) => {
      couplesByCode.set(
        code,
        referencedSnapshots[index].exists
          ? referencedSnapshots[index].data()
          : null,
      );
    });

    if (userMembershipCode && userMembershipCode !== coupleCode) {
      const membership = couplesByCode.get(userMembershipCode);
      if (!isPendingInvitationFor(membership, uid) && membership) {
        throw new HttpsError('failed-precondition', 'Ya perteneces a una pareja.');
      }
    }

    if (ownerMembershipCode && ownerMembershipCode !== coupleCode) {
      const ownerMembership = couplesByCode.get(ownerMembershipCode);
      if (!isPendingInvitationFor(ownerMembership, ownerUid) && ownerMembership) {
        throw new HttpsError(
          'failed-precondition',
          'El otro usuario ya pertenece a una pareja.',
        );
      }
    }

    const targetIsCurrent = ownerPendingCode === coupleCode ||
      (!ownerPendingCode && ownerMembershipCode === coupleCode);
    if (!targetIsCurrent) {
      throw new HttpsError('already-exists', 'Ese código ya fue utilizado.');
    }

    // Remove every pending invitation owned by the joining user, including
    // documents created by the legacy implementation.
    for (const previousCode of new Set([userPendingCode, userMembershipCode])) {
      if (!previousCode || previousCode === coupleCode) continue;
      const previous = couplesByCode.get(previousCode);
      if (isPendingInvitationFor(previous, uid)) {
        tx.delete(db.doc(`couples/${previousCode}`));
      }
    }

    tx.update(coupleRef, {
      user2: uid,
      status: 'paired',
      inviteExpiresAt: FieldValue.delete(),
      consumedAt: FieldValue.serverTimestamp(),
      consumedBy: uid,
      coins: 0,
      love: 80,
      energy: 70,
      relationshipStartDate: couple.relationshipStartDate ||
        owner.relationshipStartDate || user.relationshipStartDate || null,
      memberProfiles: {
        [ownerUid]: safeMemberProfile(ownerUid, owner),
        [uid]: safeMemberProfile(uid, user),
      },
      memberPresence: {
        [ownerUid]: { online: owner.online === true },
        [uid]: { online: user.online === true },
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(ownerRef, {
      uid: ownerUid,
      coupleCode,
      pendingCoupleCode: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(userRef, {
      uid,
      email: request.auth.token?.email || user.email || null,
      coupleCode,
      pendingCoupleCode: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { coupleCode, joined: true, alreadyJoined: false };
  });
}

async function refreshCoupleProfilesHandler(request) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const userSnapshot = await tx.get(userRef);
    if (!userSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'Completa tu perfil primero.');
    }
    const coupleCode = storedCoupleCode(userSnapshot.data()?.coupleCode);
    if (!coupleCode) {
      throw new HttpsError('failed-precondition', 'Conecta a tu pareja primero.');
    }
    const coupleRef = db.doc(`couples/${coupleCode}`);
    const coupleSnapshot = await tx.get(coupleRef);
    const couple = coupleSnapshot.data() || {};
    if (!coupleSnapshot.exists || !isActiveCouple(couple) ||
        (couple.user1 !== uid && couple.user2 !== uid)) {
      throw new HttpsError('permission-denied', 'La pareja no está activa.');
    }
    const memberIds = [couple.user1, couple.user2];
    const memberSnapshots = await Promise.all(
      memberIds.map((memberUid) => tx.get(db.doc(`users/${memberUid}`))),
    );
    if (memberSnapshots.some((snapshot) => !snapshot.exists)) {
      throw new HttpsError('failed-precondition', 'Falta un perfil de la pareja.');
    }
    const memberProfiles = {};
    const memberPresence = { ...(couple.memberPresence || {}) };
    memberIds.forEach((memberUid, index) => {
      const profile = memberSnapshots[index].data() || {};
      memberProfiles[memberUid] = safeMemberProfile(memberUid, profile);
      memberPresence[memberUid] = {
        ...(memberPresence[memberUid] || {}),
        online: profile.online === true,
      };
    });
    tx.update(coupleRef, {
      memberProfiles,
      memberPresence,
      memberProfilesUpdatedAt: FieldValue.serverTimestamp(),
    });
    return { coupleCode, refreshed: true };
  });
}

async function setCouplePresenceHandler(request) {
  const uid = requireAuth(request);
  if (typeof request.data?.online !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Estado de presencia inválido.');
  }
  const online = request.data.online;
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const userSnapshot = await tx.get(userRef);
    if (!userSnapshot.exists) return { updated: false };
    const user = userSnapshot.data() || {};
    const coupleCode = storedCoupleCode(user.coupleCode);
    let coupleRef;
    let couple;
    if (coupleCode) {
      coupleRef = db.doc(`couples/${coupleCode}`);
      const coupleSnapshot = await tx.get(coupleRef);
      couple = coupleSnapshot.data() || {};
      if (!coupleSnapshot.exists || !isActiveCouple(couple) ||
          (couple.user1 !== uid && couple.user2 !== uid)) {
        coupleRef = null;
      }
    }
    tx.update(userRef, {
      online,
      lastSeenAt: FieldValue.serverTimestamp(),
    });
    if (coupleRef) {
      tx.update(coupleRef, {
        memberPresence: {
          ...(couple.memberPresence || {}),
          [uid]: {
            online,
            lastSeenAt: FieldValue.serverTimestamp(),
          },
        },
      });
    }
    return { updated: true, coupleCode: coupleRef ? coupleCode : null };
  });
}

async function unlinkCoupleHandler(request) {
  const uid = requireAuth(request);
  if (request.data?.confirm !== true) {
    throw new HttpsError(
      'invalid-argument',
      'Debes confirmar la desvinculación.',
    );
  }

  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const userSnapshot = await tx.get(userRef);
    if (!userSnapshot.exists) {
      throw new HttpsError('not-found', 'No se encontró tu perfil.');
    }

    const user = userSnapshot.data() || {};
    const coupleCode = storedCoupleCode(user.coupleCode);
    if (!coupleCode) {
      throw new HttpsError('failed-precondition', 'No tienes una pareja activa.');
    }

    const coupleRef = db.doc(`couples/${coupleCode}`);
    const coupleSnapshot = await tx.get(coupleRef);
    if (!coupleSnapshot.exists) {
      throw new HttpsError(
        'failed-precondition',
        'La referencia de pareja está incompleta. Repara tu conexión primero.',
      );
    }

    const couple = coupleSnapshot.data() || {};
    assertMember(couple, uid);
    if (!isActiveCouple(couple)) {
      throw new HttpsError('failed-precondition', 'La pareja ya no está activa.');
    }

    const memberIds = [...new Set([couple.user1, couple.user2])];
    const memberRefs = memberIds.map((memberId) => db.doc(`users/${memberId}`));
    const memberSnapshots = await Promise.all(memberRefs.map((ref) => tx.get(ref)));

    tx.update(coupleRef, {
      status: 'unlinked',
      unlinkedAt: FieldValue.serverTimestamp(),
      unlinkedBy: uid,
      accessRevokedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    memberIds.forEach((memberId) => {
      if (memberId) {
        tx.delete(coupleRef.collection('wellnessShared').doc(memberId));
        tx.delete(coupleRef.collection('locationShares').doc(memberId));
      }
    });
    memberRefs.forEach((ref, index) => {
      if (!memberSnapshots[index].exists ||
          storedCoupleCode(memberSnapshots[index].data()?.coupleCode) !== coupleCode) {
        return;
      }
      tx.set(ref, {
        coupleCode: FieldValue.delete(),
        pendingCoupleCode: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    return { unlinked: true, coupleCode };
  });
}

async function repairCoupleMembershipHandler(request) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const firstSide = db.collection('couples').where('user1', '==', uid);
  const secondSide = db.collection('couples').where('user2', '==', uid);

  return db.runTransaction(async (tx) => {
    const [userSnapshot, firstSnapshot, secondSnapshot] = await Promise.all([
      tx.get(userRef),
      tx.get(firstSide),
      tx.get(secondSide),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError('not-found', 'No se encontró tu perfil.');
    }

    const documents = new Map();
    for (const document of [...firstSnapshot.docs, ...secondSnapshot.docs]) {
      documents.set(document.id, document);
    }
    const active = [...documents.values()].filter((document) =>
      isActiveCouple(document.data()),
    );
    if (active.length > 1) {
      logger.error('Multiple active couple memberships require manual review');
      throw new HttpsError(
        'failed-precondition',
        'Detectamos más de una pareja activa. Contacta a soporte para evitar perder datos.',
      );
    }

    const now = Date.now();
    const pending = [...documents.values()].filter((document) => {
      const invitation = document.data();
      return isPendingInvitationFor(invitation, uid) &&
        !invitationExpired(invitation, now);
    });

    if (active.length === 1) {
      const coupleCode = active[0].id;
      for (const invitation of pending) tx.delete(invitation.ref);
      tx.set(userRef, {
        coupleCode,
        pendingCoupleCode: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return { repaired: true, state: 'paired', coupleCode };
    }

    const profile = userSnapshot.data() || {};
    const referencedPending = storedCoupleCode(profile.pendingCoupleCode);
    pending.sort((first, second) => {
      if (first.id === referencedPending) return -1;
      if (second.id === referencedPending) return 1;
      const firstCreated = first.data().createdAt?.toMillis?.() || 0;
      const secondCreated = second.data().createdAt?.toMillis?.() || 0;
      return secondCreated - firstCreated;
    });
    const selected = pending[0];
    for (const invitation of pending.slice(1)) tx.delete(invitation.ref);
    for (const document of documents.values()) {
      if (document.id === selected?.id) continue;
      const invitation = document.data();
      if (isPendingInvitationFor(invitation, uid) && invitationExpired(invitation, now)) {
        tx.delete(document.ref);
      }
    }

    tx.set(userRef, {
      coupleCode: FieldValue.delete(),
      pendingCoupleCode: selected ? selected.id : FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
      repaired: true,
      state: selected ? 'pending' : 'unpaired',
      coupleCode: selected?.id || '',
    };
  });
}

async function cleanupExpiredCoupleInvitationsHandler() {
  const db = getFirestore();
  const expiredInvitations = await db.collection('couples')
    .where('inviteExpiresAt', '<=', Timestamp.now())
    .limit(100)
    .get();
  const cleanupResults = await Promise.all(expiredInvitations.docs.map((document) =>
    db.runTransaction(async (tx) => {
      const invitationRef = document.ref;
      const invitationSnapshot = await tx.get(invitationRef);
      if (!invitationSnapshot.exists) return false;

      const invitation = invitationSnapshot.data() || {};
      if (!isPendingInvitation(invitation) ||
          !invitationExpired(invitation, Date.now())) {
        return false;
      }

      const ownerUid = invitationOwner(invitation);
      const ownerRef = typeof ownerUid === 'string' && ownerUid
        ? db.doc(`users/${ownerUid}`)
        : null;
      const ownerSnapshot = ownerRef ? await tx.get(ownerRef) : null;

      tx.delete(invitationRef);
      if (ownerRef && ownerSnapshot?.exists &&
          ownerSnapshot.data()?.pendingCoupleCode === document.id) {
        tx.update(ownerRef, {
          pendingCoupleCode: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return true;
    }),
  ));
  const deleted = cleanupResults.filter(Boolean).length;

  logger.info('Expired couple invitations cleaned', { deleted });
  return { deleted };
}

async function saveSharedLayoutHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const area = request.data?.area;
  if (area !== 'garden' && area !== 'interior') {
    throw new HttpsError('invalid-argument', 'Área de diseño inválida.');
  }
  const expectedRevision = requireExpectedRevision(request.data);
  const rawLayout = request.data?.layout;

  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const layoutField = area === 'garden' ? 'gardenLayout' : 'interiorLayout';
  const revisionField = area === 'garden' ? 'gardenRevision' : 'interiorRevision';
  const timestampField = area === 'garden' ? 'gardenUpdatedAt' : 'interiorUpdatedAt';

  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(coupleRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Pareja no encontrada.');
    const couple = snapshot.data() || {};
    assertActiveMember(couple, uid);
    const currentRevision = Math.max(0, number(couple[revisionField]));
    if (currentRevision !== expectedRevision) {
      throw new HttpsError(
        'aborted',
        'El diseño cambió en el otro teléfono. Recárgalo antes de guardar.',
        { currentRevision },
      );
    }
    const layout = normalizeSharedLayout(area, rawLayout, couple);
    const revision = currentRevision + 1;
    tx.update(coupleRef, {
      [layoutField]: layout,
      [revisionField]: revision,
      [timestampField]: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { saved: true, area, revision, layout };
  });
}

async function equipHouseHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const houseId = request.data?.houseId;
  if (typeof houseId !== 'string' || !HOUSE_ITEMS.has(houseId)) {
    throw new HttpsError('invalid-argument', 'Casa inválida.');
  }

  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(coupleRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Pareja no encontrada.');
    const couple = snapshot.data() || {};
    assertActiveMember(couple, uid);
    const owned = Array.isArray(couple.ownedGardenItems)
      ? couple.ownedGardenItems
      : [];
    if (!FREE_HOUSES.has(houseId) && !owned.includes(houseId)) {
      throw new HttpsError('failed-precondition', 'La casa no pertenece al inventario compartido.');
    }
    tx.update(coupleRef, {
      selectedHouseId: houseId,
      houseUpdatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { equipped: true, houseId };
  });
}

async function performCoupleActionHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const actionId = request.data?.actionId;
  const action = typeof actionId === 'string' ? ACTIONS[actionId] : null;
  if (!action) throw new HttpsError('invalid-argument', 'Acción inválida.');

  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const today = limaDateKey();
  const claimRef = coupleRef.collection('actionClaims').doc(`${today}_${actionId}`);
  const missionRef = coupleRef.collection('missionClaims').doc(`${today}_${action.mission}`);

  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, claimSnapshot, missionSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(claimRef), tx.get(missionRef),
    ]);
    if (!coupleSnapshot.exists) throw new HttpsError('not-found', 'Pareja no encontrada.');
    const couple = coupleSnapshot.data();
    assertActiveMember(couple, uid);
    if (claimSnapshot.exists) return { awarded: false, alreadyClaimed: true };

    const mission = missionSnapshot.exists ? null : MISSION_REWARDS[action.mission];
    const coins = action.coins + (mission?.coins || 0);
    const love = action.love + (mission?.love || 0);
    const energy = action.energy + (mission?.energy || 0);
    const balanceAfter = Math.max(0, number(couple.coins) + coins);
    const receiptId = `action_${today}_${actionId}`;
    const plantWaterings = actionId === 'world_water'
      ? Math.max(
        number(couple.gardenPlant?.waterings),
        number(couple.plantsWatered),
      ) + 1
      : 0;
    const plantStage = plantWaterings >= 6 ? 3 : plantWaterings >= 3 ? 2 : 1;
    tx.update(coupleRef, {
      coins: balanceAfter,
      love: clamp(number(couple.love, 80) + love),
      energy: clamp(number(couple.energy, 70) + energy),
      plantsWatered: Math.max(0, number(couple.plantsWatered) + (action.plants || 0)),
      ...(actionId === 'world_water' ? {
        gardenPlant: {
          stage: plantStage,
          waterings: plantWaterings,
          lastWateredDate: today,
          updatedAt: FieldValue.serverTimestamp(),
        },
      } : {}),
      lastAction: action.label,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(claimRef, { actionId, claimedBy: uid, createdAt: FieldValue.serverTimestamp() });
    tx.create(coupleRef.collection('economyLedger').doc(receiptId), {
      type: 'action',
      actionId,
      actorUid: uid,
      deltaCoins: coins,
      deltaLove: love,
      deltaEnergy: energy,
      balanceAfter,
      dateKey: today,
      createdAt: FieldValue.serverTimestamp(),
    });
    if (!missionSnapshot.exists) {
      tx.create(missionRef, { missionId: action.mission, claimedBy: uid, createdAt: FieldValue.serverTimestamp() });
    }
    return {
      awarded: true,
      coins,
      love,
      energy,
      balanceAfter,
      receiptId,
      ...(actionId === 'world_water' ? { plantStage, plantWaterings } : {}),
      missionCompleted: !missionSnapshot.exists,
    };
  });
}

async function purchaseItemHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const itemId = request.data?.itemId;
  const item = typeof itemId === 'string' ? SHOP_ITEMS[itemId] : null;
  if (!item) throw new HttpsError('invalid-argument', 'Objeto inválido o premium.');

  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const receiptId = `purchase_${itemId}`;
  const receiptRef = coupleRef.collection('economyLedger').doc(receiptId);
  return db.runTransaction(async (tx) => {
    const [snapshot, receiptSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(receiptRef),
    ]);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Pareja no encontrada.');
    const couple = snapshot.data();
    assertActiveMember(couple, uid);
    const owned = Array.isArray(couple[item.field]) ? couple[item.field] : [];
    const balance = number(couple.coins);
    if (owned.includes(itemId)) {
      const receipt = receiptSnapshot.data() || {};
      return {
        purchased: false,
        alreadyOwned: true,
        coins: balance,
        balanceAfter: receiptSnapshot.exists
          ? number(receipt.balanceAfter, balance)
          : balance,
        priceCharged: receiptSnapshot.exists
          ? number(receipt.priceCharged, item.price)
          : 0,
        receiptId,
      };
    }
    if (receiptSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'El historial de la compra es inconsistente.');
    }
    if (balance < item.price) throw new HttpsError('failed-precondition', 'Monedas insuficientes.');
    const balanceAfter = balance - item.price;
    tx.update(coupleRef, {
      coins: balanceAfter,
      [item.field]: FieldValue.arrayUnion(itemId),
      lastShopPurchase: item.name,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(receiptRef, {
      type: 'purchase',
      itemId,
      itemName: item.name,
      actorUid: uid,
      priceCharged: item.price,
      deltaCoins: -item.price,
      balanceAfter,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {
      purchased: true,
      alreadyOwned: false,
      coins: balanceAfter,
      balanceAfter,
      priceCharged: item.price,
      receiptId,
    };
  });
}

async function claimDailyRewardHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const today = limaDateKey();
  const yesterday = previousDateKey();
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(coupleRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Pareja no encontrada.');
    const couple = snapshot.data();
    assertActiveMember(couple, uid);
    const chest = couple.dailyChest || {};
    if (chest.lastClaimDate === today) return { awarded: false, alreadyClaimed: true };
    let streak = chest.lastClaimDate === yesterday ? number(chest.streak) + 1 : 1;
    if (streak > 7) streak = 1;
    const reward = DAILY_REWARDS[streak];
    const balanceAfter = Math.max(0, number(couple.coins) + reward.coins);
    const receiptId = `daily_${today}`;
    tx.update(coupleRef, {
      coins: balanceAfter,
      love: clamp(number(couple.love, 80) + reward.love),
      energy: clamp(number(couple.energy, 70) + reward.energy),
      dailyChest: {
        lastClaimDate: today,
        streak,
        totalClaims: number(chest.totalClaims) + 1,
        lastRewardCoins: reward.coins,
        lastRewardLove: reward.love,
        lastRewardEnergy: reward.energy,
        lastRewardTitle: reward.title,
        rewardedTo: uid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      lastAction: `Reclamaron el cofre diario: ${reward.title}`,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(coupleRef.collection('economyLedger').doc(receiptId), {
      type: 'daily_reward',
      actorUid: uid,
      streak,
      deltaCoins: reward.coins,
      deltaLove: reward.love,
      deltaEnergy: reward.energy,
      balanceAfter,
      dateKey: today,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { awarded: true, streak, ...reward, balanceAfter, receiptId };
  });
}

async function saveWellnessSettingsHandler(request) {
  const uid = requireAuth(request);
  const cycleLength = request.data?.cycleLength;
  const periodLength = request.data?.periodLength;
  const remindersEnabled = request.data?.remindersEnabled === true;
  const sharingEnabled = request.data?.sharingEnabled === true;
  if (!Number.isInteger(cycleLength) || cycleLength < 21 || cycleLength > 45 ||
      !Number.isInteger(periodLength) || periodLength < 2 || periodLength > 10) {
    throw new HttpsError('invalid-argument', 'La duración del ciclo o periodo no es válida.');
  }
  const sharedFields = wellnessStringSet(
    request.data?.sharedFields,
    WELLNESS_SHARED_FIELDS,
    WELLNESS_SHARED_FIELDS.size,
  );
  if (!sharingEnabled && sharedFields.length) {
    throw new HttpsError('invalid-argument', 'Activa el consentimiento antes de compartir campos.');
  }

  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const settingsRef = userRef.collection('wellness').doc('settings');
  return db.runTransaction(async (tx) => {
    const userSnapshot = await tx.get(userRef);
    if (!userSnapshot.exists) throw new HttpsError('not-found', 'Perfil no encontrado.');
    const user = userSnapshot.data() || {};
    const coupleCode = storedCoupleCode(user.coupleCode);
    let coupleRef = null;
    if (coupleCode) {
      coupleRef = db.doc(`couples/${coupleCode}`);
      const coupleSnapshot = await tx.get(coupleRef);
      const couple = coupleSnapshot.data() || {};
      if (sharingEnabled) {
        if (!coupleSnapshot.exists || !isActiveCouple(couple) ||
            (couple.user1 !== uid && couple.user2 !== uid)) {
          throw new HttpsError('failed-precondition', 'Necesitas una pareja activa para compartir.');
        }
      }
    } else if (sharingEnabled) {
      throw new HttpsError('failed-precondition', 'Necesitas una pareja activa para compartir.');
    }

    tx.set(settingsRef, {
      enabled: true,
      cycleLength,
      periodLength,
      remindersEnabled,
      sharingEnabled,
      sharedFields: sharingEnabled ? sharedFields : [],
      consentVersion: sharingEnabled ? 1 : 0,
      consentUpdatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    if (coupleRef && !sharingEnabled) {
      tx.delete(coupleRef.collection('wellnessShared').doc(uid));
    }
    return { saved: true, sharingEnabled, sharedFields };
  });
}

async function startLocationSharingHandler(request) {
  const uid = requireAuth(request);
  const mode = request.data?.mode;
  const approximate = request.data?.approximate;
  if (!Object.hasOwn(LOCATION_MODES, mode) || typeof approximate !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Modo de ubicación no permitido.');
  }
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const userSnapshot = await tx.get(userRef);
    if (!userSnapshot.exists) throw new HttpsError('not-found', 'Perfil no encontrado.');
    const coupleCode = storedCoupleCode(userSnapshot.data()?.coupleCode);
    if (!coupleCode) throw new HttpsError('failed-precondition', 'Conecta a tu pareja primero.');
    const coupleRef = db.doc(`couples/${coupleCode}`);
    const coupleSnapshot = await tx.get(coupleRef);
    const couple = coupleSnapshot.data() || {};
    assertActiveMember(couple, uid);
    const sessionId = randomUUID();
    const duration = LOCATION_MODES[mode];
    const now = Date.now();
    const endsAtMillis = duration == null || duration === 0 ? null : now + duration;
    const safetyExpiryMillis = mode === 'point'
      ? now + LOCATION_POINT_TTL_MS
      : now + LOCATION_STALE_TTL_MS;
    const expiresAtMillis = endsAtMillis == null
      ? safetyExpiryMillis
      : Math.min(endsAtMillis, safetyExpiryMillis);
    const shareRef = coupleRef.collection('locationShares').doc(uid);
    const previousShare = await tx.get(shareRef);
    const previousStartedAt = previousShare.data()?.startedAt;
    if (previousStartedAt instanceof Timestamp &&
        now - previousStartedAt.toMillis() < LOCATION_SESSION_START_COOLDOWN_MS) {
      throw new HttpsError(
        'resource-exhausted',
        'Espera unos segundos antes de iniciar otra sesión.',
      );
    }
    tx.set(shareRef, {
      ownerUid: uid,
      sessionId,
      mode,
      approximate,
      active: true,
      startedAt: FieldValue.serverTimestamp(),
      endsAt: endsAtMillis == null ? null : Timestamp.fromMillis(endsAtMillis),
      expiresAt: Timestamp.fromMillis(expiresAtMillis),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { started: true, coupleCode, sessionId, mode, approximate };
  });
}

async function updateSharedLocationHandler(request) {
  const uid = requireAuth(request);
  const sessionId = request.data?.sessionId;
  const latitude = request.data?.latitude;
  const longitude = request.data?.longitude;
  const accuracy = request.data?.accuracy;
  if (typeof sessionId !== 'string' || sessionId.length < 20 ||
      typeof latitude !== 'number' || !Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      typeof longitude !== 'number' || !Number.isFinite(longitude) || longitude < -180 || longitude > 180 ||
      typeof accuracy !== 'number' || !Number.isFinite(accuracy) || accuracy < 0 || accuracy > 100000) {
    throw new HttpsError('invalid-argument', 'Coordenadas no válidas.');
  }
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const userSnapshot = await tx.get(userRef);
    if (!userSnapshot.exists) throw new HttpsError('not-found', 'Perfil no encontrado.');
    const coupleCode = storedCoupleCode(userSnapshot.data()?.coupleCode);
    if (!coupleCode) throw new HttpsError('failed-precondition', 'No tienes una pareja activa.');
    const coupleRef = db.doc(`couples/${coupleCode}`);
    const shareRef = coupleRef.collection('locationShares').doc(uid);
    const [coupleSnapshot, shareSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(shareRef),
    ]);
    const couple = coupleSnapshot.data() || {};
    assertActiveMember(couple, uid);
    if (!shareSnapshot.exists) throw new HttpsError('not-found', 'No hay una sesión activa.');
    const share = shareSnapshot.data() || {};
    if (share.sessionId !== sessionId || share.active !== true) {
      throw new HttpsError('failed-precondition', 'La sesión de ubicación ya terminó.');
    }
    if (share.endsAt instanceof Timestamp && share.endsAt.toMillis() <= Date.now()) {
      tx.delete(shareRef);
      return { accepted: false, expired: true };
    }
    const lastUpdate = share.locationUpdatedAt instanceof Timestamp
      ? share.locationUpdatedAt.toMillis()
      : 0;
    if (share.mode !== 'point' && Date.now() - lastUpdate < LOCATION_UPDATE_COOLDOWN_MS) {
      return { accepted: false, throttled: true };
    }
    const approximate = share.approximate === true;
    const normalizedLatitude = approximate
      ? Math.round(latitude * 100) / 100
      : Math.round(latitude * 1000000) / 1000000;
    const normalizedLongitude = approximate
      ? Math.round(longitude * 100) / 100
      : Math.round(longitude * 1000000) / 1000000;
    const point = share.mode === 'point';
    const endsAtMillis = share.endsAt instanceof Timestamp
      ? share.endsAt.toMillis()
      : null;
    const safetyExpiryMillis = Date.now() + LOCATION_STALE_TTL_MS;
    const expiresAtMillis = point
      ? Date.now() + LOCATION_POINT_TTL_MS
      : endsAtMillis == null
        ? safetyExpiryMillis
        : Math.min(endsAtMillis, safetyExpiryMillis);
    tx.update(shareRef, {
      latitude: normalizedLatitude,
      longitude: normalizedLongitude,
      accuracyMeters: approximate ? Math.max(accuracy, 1000) : accuracy,
      active: !point,
      locationUpdatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(expiresAtMillis),
    });
    return { accepted: true, point, approximate };
  });
}

async function stopLocationSharingHandler(request) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const userSnapshot = await tx.get(userRef);
    if (!userSnapshot.exists) return { stopped: false };
    const coupleCode = storedCoupleCode(userSnapshot.data()?.coupleCode);
    if (!coupleCode) return { stopped: false };
    const coupleRef = db.doc(`couples/${coupleCode}`);
    const coupleSnapshot = await tx.get(coupleRef);
    const couple = coupleSnapshot.data() || {};
    if (!coupleSnapshot.exists ||
        (couple.user1 !== uid && couple.user2 !== uid)) {
      return { stopped: false };
    }
    tx.delete(coupleRef.collection('locationShares').doc(uid));
    return { stopped: true };
  });
}

async function cleanupExpiredLocationSharesHandler() {
  const db = getFirestore();
  const snapshot = await db.collectionGroup('locationShares')
    .where('expiresAt', '<=', Timestamp.now())
    .limit(400)
    .get();
  if (snapshot.empty) return { deleted: 0 };
  const batch = db.batch();
  snapshot.docs.forEach((document) => batch.delete(document.ref));
  await batch.commit();
  logger.info('Expired location shares cleaned', { deleted: snapshot.size });
  return { deleted: snapshot.size };
}

async function saveWellnessEntryHandler(request) {
  const uid = requireAuth(request);
  const dateKey = requireWellnessDateKey(request.data);
  const mood = request.data?.mood;
  const flow = request.data?.flow;
  if (typeof mood !== 'string' || !WELLNESS_MOODS.has(mood) ||
      typeof flow !== 'string' || !WELLNESS_FLOWS.has(flow)) {
    throw new HttpsError('invalid-argument', 'Ánimo o intensidad no permitidos.');
  }
  const symptoms = wellnessStringSet(request.data?.symptoms, WELLNESS_SYMPTOMS, 8);
  const notes = typeof request.data?.notes === 'string' ? request.data.notes.trim() : '';
  if (notes.length > 1000) throw new HttpsError('invalid-argument', 'La nota supera 1000 caracteres.');
  const periodStarted = request.data?.periodStarted === true;
  const periodEnded = request.data?.periodEnded === true;
  if (periodStarted && periodEnded) {
    throw new HttpsError('invalid-argument', 'El inicio y final deben registrarse en días distintos.');
  }

  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const settingsRef = userRef.collection('wellness').doc('settings');
  const entryRef = userRef.collection('wellnessEntries').doc(dateKey);
  return db.runTransaction(async (tx) => {
    const [userSnapshot, settingsSnapshot, entrySnapshot] = await Promise.all([
      tx.get(userRef), tx.get(settingsRef), tx.get(entryRef),
    ]);
    if (!userSnapshot.exists) throw new HttpsError('not-found', 'Perfil no encontrado.');
    const settings = settingsSnapshot.data() || {};
    if (!settingsSnapshot.exists || settings.enabled !== true) {
      throw new HttpsError('failed-precondition', 'Activa primero el módulo de bienestar.');
    }
    const user = userSnapshot.data() || {};
    const coupleCode = storedCoupleCode(user.coupleCode);
    let sharedRef = null;
    if (coupleCode && settings.sharingEnabled === true) {
      const coupleRef = db.doc(`couples/${coupleCode}`);
      const coupleSnapshot = await tx.get(coupleRef);
      const couple = coupleSnapshot.data() || {};
      if (coupleSnapshot.exists && isActiveCouple(couple) &&
          (couple.user1 === uid || couple.user2 === uid)) {
        sharedRef = coupleRef.collection('wellnessShared').doc(uid);
      }
    }

    const entry = {
      ownerUid: uid,
      dateKey,
      mood,
      flow,
      symptoms,
      notes,
      periodStarted,
      periodEnded,
      createdAt: entrySnapshot.exists
        ? entrySnapshot.data().createdAt || FieldValue.serverTimestamp()
        : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    tx.set(entryRef, entry);
    if (sharedRef) {
      const sharedFields = wellnessStringSet(
        settings.sharedFields,
        WELLNESS_SHARED_FIELDS,
        WELLNESS_SHARED_FIELDS.size,
      );
      const payload = wellnessSharedPayload(entry, sharedFields);
      if (Object.keys(payload).length) {
        tx.set(sharedRef, {
          ownerUid: uid,
          sourceDateKey: dateKey,
          fields: sharedFields,
          ...payload,
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        tx.delete(sharedRef);
      }
    }
    return { saved: true, dateKey, shared: Boolean(sharedRef) };
  });
}

async function deleteWellnessEntryHandler(request) {
  const uid = requireAuth(request);
  const dateKey = requireWellnessDateKey(request.data);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const entryRef = userRef.collection('wellnessEntries').doc(dateKey);
  return db.runTransaction(async (tx) => {
    const [userSnapshot, entrySnapshot] = await Promise.all([
      tx.get(userRef), tx.get(entryRef),
    ]);
    if (!userSnapshot.exists) throw new HttpsError('not-found', 'Perfil no encontrado.');
    const coupleCode = storedCoupleCode(userSnapshot.data()?.coupleCode);
    let sharedRef = null;
    let sharedSnapshot = null;
    if (coupleCode) {
      sharedRef = db.doc(`couples/${coupleCode}/wellnessShared/${uid}`);
      sharedSnapshot = await tx.get(sharedRef);
    }
    tx.delete(entryRef);
    if (sharedRef && sharedSnapshot.exists &&
        sharedSnapshot.data()?.sourceDateKey === dateKey) {
      tx.delete(sharedRef);
    }
    return { deleted: entrySnapshot.exists, dateKey };
  });
}

async function deleteWellnessDataHandler(request) {
  const uid = requireAuth(request);
  if (request.data?.confirm !== true) {
    throw new HttpsError('invalid-argument', 'Debes confirmar la eliminación total.');
  }
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const userSnapshot = await userRef.get();
  if (!userSnapshot.exists) throw new HttpsError('not-found', 'Perfil no encontrado.');
  const entries = await userRef.collection('wellnessEntries').get();
  let batch = db.batch();
  let operations = 0;
  for (const document of entries.docs) {
    batch.delete(document.ref);
    operations += 1;
    if (operations === 400) {
      await batch.commit();
      batch = db.batch();
      operations = 0;
    }
  }
  batch.delete(userRef.collection('wellness').doc('settings'));
  const coupleCode = storedCoupleCode(userSnapshot.data()?.coupleCode);
  if (coupleCode) batch.delete(db.doc(`couples/${coupleCode}/wellnessShared/${uid}`));
  await batch.commit();
  return { deleted: true, entriesDeleted: entries.size };
}

async function joinLudoHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const gameRef = coupleRef.collection('games').doc('ludo');
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, gameSnapshot, userSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(gameRef), tx.get(userRef),
    ]);
    if (!coupleSnapshot.exists) throw new HttpsError('not-found', 'Pareja no encontrada.');
    const couple = coupleSnapshot.data();
    assertActiveMember(couple, uid);
    const side = couple.user1 === uid ? 'A' : 'B';
    const name = userSnapshot.data()?.name || request.auth.token.email || `Jugador ${side}`;
    if (!gameSnapshot.exists) {
      tx.create(gameRef, {
        gameId: 'ludo',
        players: { A: couple.user1 || '', B: couple.user2 || '' },
        playerNames: { A: side === 'A' ? name : '', B: side === 'B' ? name : '' },
        tokens: { A: [-1, -1, -1, -1], B: [-1, -1, -1, -1] },
        joinedBy: [uid], restartRequestedBy: [], abandonedBy: '', round: 1,
        turnSide: 'A', dice: 0, phase: 'waiting', winnerSide: '',
        lastMove: 'Juego creado 🎲', createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      const joinedBy = [...new Set([...(gameSnapshot.data().joinedBy || []), uid])];
      const nextPhase = gameSnapshot.data().phase === 'waiting' && joinedBy.length === 2
        ? 'roll'
        : gameSnapshot.data().phase;
      tx.update(gameRef, {
        [`players.${side}`]: uid,
        [`playerNames.${side}`]: name,
        joinedBy,
        phase: nextPhase,
        lastMove: nextPhase === 'roll' && gameSnapshot.data().phase === 'waiting'
          ? 'Ambos jugadores listos. Lanza el dado.'
          : gameSnapshot.data().lastMove,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return { side };
  });
}

async function rollLudoDiceHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const gameRef = db.doc(`couples/${coupleCode}/games/ludo`);
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, gameSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(gameRef),
    ]);
    if (!coupleSnapshot.exists || !gameSnapshot.exists) {
      throw new HttpsError('not-found', 'Partida no encontrada.');
    }
    assertActiveMember(coupleSnapshot.data(), uid);
    const game = gameSnapshot.data();
    const side = game.players?.A === uid ? 'A' : game.players?.B === uid ? 'B' : null;
    if (!side) throw new HttpsError('permission-denied', 'No participas en esta partida.');
    if (!(game.joinedBy || []).includes(game.players?.A) ||
        !(game.joinedBy || []).includes(game.players?.B)) {
      throw new HttpsError('failed-precondition', 'Espera a que tu pareja entre a la sala.');
    }
    if (game.winnerSide || game.phase === 'finished') throw new HttpsError('failed-precondition', 'La partida terminó.');
    if (game.turnSide !== side || game.phase !== 'roll') throw new HttpsError('failed-precondition', 'No puedes lanzar ahora.');
    const dice = randomInt(1, 7);
    const tokens = tokenList(game.tokens?.[side]);
    const hasMove = tokens.some((position) => legalMove(position, dice));
    const opponent = otherSide(side);
    const nextSide = game.players?.[opponent] ? opponent : side;
    tx.update(gameRef, hasMove ? {
      dice, phase: 'choose', lastMove: `Salió ${dice}. Elige una ficha.`,
      updatedAt: FieldValue.serverTimestamp(),
    } : {
      dice, phase: 'roll', turnSide: nextSide,
      lastMove: `Salió ${dice}, sin movimientos. Turno de ${nextSide}.`,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { dice, hasMove, turnSide: hasMove ? side : nextSide };
  });
}

async function moveLudoTokenHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const tokenIndex = request.data?.tokenIndex;
  if (!Number.isInteger(tokenIndex) || tokenIndex < 0 || tokenIndex > 3) {
    throw new HttpsError('invalid-argument', 'Ficha inválida.');
  }
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const gameRef = coupleRef.collection('games').doc('ludo');
  const rewardClaimRef = coupleRef.collection('gameRewardClaims').doc(`${limaDateKey()}_ludo`);
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, gameSnapshot, rewardClaimSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(gameRef), tx.get(rewardClaimRef),
    ]);
    if (!coupleSnapshot.exists || !gameSnapshot.exists) throw new HttpsError('not-found', 'Partida no encontrada.');
    const couple = coupleSnapshot.data();
    assertActiveMember(couple, uid);
    const game = gameSnapshot.data();
    const side = game.players?.A === uid ? 'A' : game.players?.B === uid ? 'B' : null;
    if (!side) throw new HttpsError('permission-denied', 'No participas en esta partida.');
    if (!(game.joinedBy || []).includes(game.players?.A) ||
        !(game.joinedBy || []).includes(game.players?.B)) {
      throw new HttpsError('failed-precondition', 'Espera a que tu pareja entre a la sala.');
    }
    if (game.winnerSide || game.phase === 'finished') throw new HttpsError('failed-precondition', 'La partida terminó.');
    if (game.turnSide !== side || game.phase !== 'choose') throw new HttpsError('failed-precondition', 'No puedes mover ahora.');
    const dice = number(game.dice);
    const mine = tokenList(game.tokens?.[side]);
    const opponentSide = otherSide(side);
    const opponents = tokenList(game.tokens?.[opponentSide]);
    const current = mine[tokenIndex];
    if (!legalMove(current, dice)) throw new HttpsError('failed-precondition', 'Movimiento inválido.');
    const position = current < 0 ? 0 : Math.min(LUDO_FINISH, current + dice);
    mine[tokenIndex] = position;
    let captured = false;
    if (position < LUDO_FINISH) {
      const index = trackIndex(side, position);
      for (let i = 0; i < opponents.length; i += 1) {
        if (opponents[i] >= 0 && opponents[i] < LUDO_FINISH &&
            trackIndex(opponentSide, opponents[i]) === index) {
          opponents[i] = -1;
          captured = true;
        }
      }
    }
    const won = mine.every((value) => value >= LUDO_FINISH);
    const nextSide = dice === 6 || !game.players?.[opponentSide] ? side : opponentSide;
    const tokens = side === 'A' ? { A: mine, B: opponents } : { A: opponents, B: mine };
    const playerName = game.playerNames?.[side] || `Jugador ${side}`;
    const gameUpdate = {
      tokens,
      turnSide: won ? side : nextSide,
      dice: 0,
      phase: won ? 'finished' : 'roll',
      winnerSide: won ? side : '',
      lastMove: won ? `${playerName} ganó la partida 👑` :
        captured ? `${playerName} capturó una ficha` : `${playerName} movió una ficha`,
      updatedAt: FieldValue.serverTimestamp(),
    };
    let rewardAwarded = false;
    if (won && !rewardClaimSnapshot.exists) {
      gameUpdate.rewardGranted = true;
      gameUpdate.rewardedAt = FieldValue.serverTimestamp();
      gameUpdate.rewardedTo = uid;
      tx.create(rewardClaimRef, {
        gameId: 'ludo', claimedBy: uid, dateKey: limaDateKey(),
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(coupleRef, {
        coins: Math.max(0, number(couple.coins) + 80),
        love: clamp(number(couple.love, 80) + 4),
        lastAction: 'Recompensa de Ludo entregada',
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.create(coupleRef.collection('economyLedger').doc(`game_${limaDateKey()}_ludo`), {
        type: 'game_reward', gameId: 'ludo', actorUid: uid,
        deltaCoins: 80, deltaLove: 4,
        balanceAfter: {
          coins: Math.max(0, number(couple.coins) + 80),
          love: clamp(number(couple.love, 80) + 4),
        },
        dateKey: limaDateKey(), createdAt: FieldValue.serverTimestamp(),
      });
      rewardAwarded = true;
    } else if (won) {
      gameUpdate.rewardGranted = false;
    }
    tx.update(gameRef, gameUpdate);
    return { moved: true, captured, won, winnerSide: won ? side : '', winnerName: playerName, rewardAwarded };
  });
}

async function resetLudoHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const gameRef = coupleRef.collection('games').doc('ludo');
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, gameSnapshot] = await Promise.all([tx.get(coupleRef), tx.get(gameRef)]);
    if (!coupleSnapshot.exists || !gameSnapshot.exists) throw new HttpsError('not-found', 'Partida no encontrada.');
    const couple = coupleSnapshot.data();
    assertActiveMember(couple, uid);
    const game = gameSnapshot.data();
    if (game.phase !== 'finished') throw new HttpsError('failed-precondition', 'Solo puedes reiniciar una partida terminada.');
    const restartRequestedBy = [...new Set([...(game.restartRequestedBy || []), uid])];
    const players = [couple.user1, couple.user2].filter(Boolean);
    const approved = players.length === 2 && players.every((id) => restartRequestedBy.includes(id));
    if (!approved) {
      tx.update(gameRef, {
        restartRequestedBy,
        lastMove: 'Revancha solicitada. Falta la confirmacion de tu pareja.',
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { reset: false, approved: false, restartRequestedBy };
    }
    tx.update(gameRef, {
      tokens: { A: [-1, -1, -1, -1], B: [-1, -1, -1, -1] },
      round: number(game.round, 1) + 1,
      turnSide: number(game.round, 1) % 2 === 0 ? 'A' : 'B',
      dice: 0, phase: 'roll', winnerSide: '', restartRequestedBy: [], abandonedBy: '',
      rewardGranted: FieldValue.delete(), rewardedAt: FieldValue.delete(),
      rewardedTo: FieldValue.delete(), lastMove: 'Nueva partida iniciada 🎲',
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { reset: true, approved: true, restartRequestedBy: [] };
  });
}

async function abandonLudoHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const gameRef = coupleRef.collection('games').doc('ludo');
  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, gameSnapshot] = await Promise.all([tx.get(coupleRef), tx.get(gameRef)]);
    if (!coupleSnapshot.exists || !gameSnapshot.exists) throw new HttpsError('not-found', 'Partida no encontrada.');
    const couple = coupleSnapshot.data();
    assertActiveMember(couple, uid);
    const game = gameSnapshot.data();
    if (game.phase === 'finished') return { abandoned: false, alreadyFinished: true };
    const side = game.players?.A === uid ? 'A' : game.players?.B === uid ? 'B' : null;
    if (!side) throw new HttpsError('permission-denied', 'No participas en esta partida.');
    const winnerSide = otherSide(side);
    tx.update(gameRef, {
      phase: 'finished', winnerSide, abandonedBy: uid, dice: 0,
      restartRequestedBy: [],
      lastMove: `${game.playerNames?.[side] || `Jugador ${side}`} abandono la partida. Sin recompensa.`,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { abandoned: true, winnerSide, rewardAwarded: false };
  });
}

async function openMiniGameHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const gameId = requireMiniGameId(request.data);
  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const gameRef = coupleRef.collection('games').doc(gameId);
  const privateRef = db.doc(`privateGameState/${coupleCode}__${gameId}`);

  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, gameSnapshot, privateSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(gameRef), tx.get(privateRef),
    ]);
    if (!coupleSnapshot.exists) throw new HttpsError('not-found', 'Pareja no encontrada.');
    const couple = coupleSnapshot.data();
    assertActiveMember(couple, uid);
    if (!couple.user1 || !couple.user2) {
      throw new HttpsError('failed-precondition', 'Tu pareja debe estar conectada para jugar.');
    }
    if (!gameSnapshot.exists) {
      const state = initialMiniGame(gameId, couple);
      state.publicState.joinedBy = [uid];
      tx.create(gameRef, state.publicState);
      tx.set(privateRef, state.privateState);
    } else if (!privateSnapshot.exists) {
      const state = initialMiniGame(gameId, couple);
      state.publicState.joinedBy = [uid];
      tx.set(gameRef, state.publicState);
      tx.set(privateRef, state.privateState);
    } else {
      tx.update(gameRef, {
        joinedBy: [...new Set([...(gameSnapshot.data().joinedBy || []), uid])],
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return { opened: true };
  });
}

async function playMiniGameHandler(request) {
  const uid = requireAuth(request);
  const coupleCode = requireCoupleCode(request.data);
  const gameId = requireMiniGameId(request.data);
  const action = request.data?.action;
  const payload = request.data?.payload;
  if (typeof action !== 'string' || !payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new HttpsError('invalid-argument', 'Jugada inválida.');
  }

  const db = getFirestore();
  const coupleRef = db.doc(`couples/${coupleCode}`);
  const gameRef = coupleRef.collection('games').doc(gameId);
  const privateRef = db.doc(`privateGameState/${coupleCode}__${gameId}`);
  const claimRef = coupleRef.collection('gameRewardClaims').doc(`${limaDateKey()}_${gameId}`);

  return db.runTransaction(async (tx) => {
    const [coupleSnapshot, gameSnapshot, privateSnapshot, claimSnapshot] = await Promise.all([
      tx.get(coupleRef), tx.get(gameRef), tx.get(privateRef), tx.get(claimRef),
    ]);
    if (!coupleSnapshot.exists || !gameSnapshot.exists || !privateSnapshot.exists) {
      throw new HttpsError('not-found', 'Abre el juego antes de realizar una jugada.');
    }
    const couple = coupleSnapshot.data();
    assertActiveMember(couple, uid);
    const game = gameSnapshot.data();
    const privateState = privateSnapshot.data();
    const players = [couple.user1, couple.user2].filter(Boolean);

    if (action === 'abandon') {
      if (game.phase === 'complete') return { abandoned: false, alreadyComplete: true };
      const winnerUid = players.find((id) => id !== uid) || '';
      tx.update(gameRef, {
        phase: 'complete', abandonedBy: uid, winnerUid,
        restartRequestedBy: [], updatedAt: FieldValue.serverTimestamp(),
      });
      return { abandoned: true, winnerUid, rewardAwarded: false };
    }

    if (action === 'next' || action === 'request_restart') {
      const restartRequestedBy = [...new Set([...(game.restartRequestedBy || []), uid])];
      const approved = players.length === 2 && players.every((id) => restartRequestedBy.includes(id));
      if (game.phase === 'complete' && !approved) {
        tx.update(gameRef, { restartRequestedBy, updatedAt: FieldValue.serverTimestamp() });
        return { next: false, approved: false, restartRequestedBy };
      }
      if (game.phase !== 'complete') throw new HttpsError('failed-precondition', 'La ronda todavía no terminó.');
      const state = nextMiniGameState(gameId, couple, game.round);
      state.publicState.joinedBy = [...players];
      tx.set(gameRef, state.publicState);
      tx.set(privateRef, state.privateState);
      return { next: true, approved: true, restartRequestedBy: [] };
    }

    if (players.length !== 2 || !players.every((id) => (game.joinedBy || []).includes(id))) {
      throw new HttpsError('failed-precondition', 'Espera a que tu pareja entre a la sala.');
    }

    if (gameId === 'couple_questions') {
      if (action !== 'answer' || game.phase !== 'answering') throw new HttpsError('failed-precondition', 'No puedes responder ahora.');
      const text = typeof payload.text === 'string' ? payload.text.trim() : '';
      if (!text || text.length > 300) throw new HttpsError('invalid-argument', 'La respuesta debe tener entre 1 y 300 caracteres.');
      const answers = { ...(privateState.answers || {}) };
      if (answers[uid]) throw new HttpsError('already-exists', 'Ya respondiste esta pregunta.');
      answers[uid] = text;
      const answeredBy = Object.keys(answers).filter((id) => players.includes(id));
      const complete = players.length === 2 && players.every((id) => answeredBy.includes(id));
      tx.update(privateRef, { answers, updatedAt: FieldValue.serverTimestamp() });
      tx.update(gameRef, {
        answeredBy,
        answers: complete ? answers : {},
        phase: complete ? 'complete' : 'answering',
        updatedAt: FieldValue.serverTimestamp(),
      });
      const rewardAwarded = complete && rewardMiniGame(tx, coupleRef, claimRef, claimSnapshot, couple, gameId, uid);
      return { accepted: true, complete, rewardAwarded };
    }

    if (gameId === 'challenge_roulette') {
      if (action === 'spin') {
        if (game.phase !== 'active' || (game.confirmedBy || []).length) {
          throw new HttpsError('failed-precondition', 'No puedes cambiar un reto ya confirmado.');
        }
        const challengeIndex = randomInt(0, COUPLE_CHALLENGES.length);
        tx.update(privateRef, { challengeIndex, updatedAt: FieldValue.serverTimestamp() });
        tx.update(gameRef, { challenge: COUPLE_CHALLENGES[challengeIndex], updatedAt: FieldValue.serverTimestamp() });
        return { spun: true };
      }
      if (action !== 'confirm' || game.phase !== 'active') throw new HttpsError('failed-precondition', 'Acción no disponible.');
      const confirmedBy = [...new Set([...(game.confirmedBy || []), uid])];
      const complete = players.length === 2 && players.every((id) => confirmedBy.includes(id));
      tx.update(gameRef, { confirmedBy, phase: complete ? 'complete' : 'active', updatedAt: FieldValue.serverTimestamp() });
      const rewardAwarded = complete && rewardMiniGame(tx, coupleRef, claimRef, claimSnapshot, couple, gameId, uid);
      return { confirmed: true, complete, rewardAwarded };
    }

    if (gameId === 'couple_memory') {
      const deck = Array.isArray(privateState.deck) ? privateState.deck : [];
      if (deck.length !== 16) throw new HttpsError('failed-precondition', 'Tablero inválido. Reinicia la partida.');
      if (action === 'continue') {
        if (game.phase !== 'resolve') throw new HttpsError('failed-precondition', 'No puedes continuar ahora.');
        const cards = Array.isArray(game.cards) ? [...game.cards] : Array(16).fill('');
        for (const index of game.revealed || []) cards[index] = '';
        const turnUid = players.find((id) => id !== game.turnUid) || game.turnUid;
        tx.update(gameRef, { cards, revealed: [], phase: 'playing', turnUid, updatedAt: FieldValue.serverTimestamp() });
        return { continued: true };
      }
      if (action !== 'flip' || game.phase !== 'playing' || game.turnUid !== uid) {
        throw new HttpsError('failed-precondition', 'No es tu turno.');
      }
      const index = payload.index;
      if (!Number.isInteger(index) || index < 0 || index >= 16) throw new HttpsError('invalid-argument', 'Carta inválida.');
      const matched = Array.isArray(game.matched) ? [...game.matched] : [];
      const revealed = Array.isArray(game.revealed) ? [...game.revealed] : [];
      if (matched.includes(index) || revealed.includes(index)) throw new HttpsError('failed-precondition', 'Esa carta ya está visible.');
      const cards = Array.isArray(game.cards) ? [...game.cards] : Array(16).fill('');
      cards[index] = deck[index];
      if (revealed.length === 0) {
        tx.update(gameRef, { cards, revealed: [index], updatedAt: FieldValue.serverTimestamp() });
        return { flipped: true, first: true };
      }
      const first = revealed[0];
      const isMatch = deck[first] === deck[index];
      const moves = number(game.moves) + 1;
      if (isMatch) {
        const nextMatched = [...matched, first, index];
        const complete = nextMatched.length === 16;
        tx.update(gameRef, {
          cards,
          revealed: [],
          matched: nextMatched,
          moves,
          phase: complete ? 'complete' : 'playing',
          updatedAt: FieldValue.serverTimestamp(),
        });
        const rewardAwarded = complete && rewardMiniGame(tx, coupleRef, claimRef, claimSnapshot, couple, gameId, uid);
        return { flipped: true, match: true, complete, rewardAwarded };
      }
      tx.update(gameRef, { cards, revealed: [first, index], moves, phase: 'resolve', updatedAt: FieldValue.serverTimestamp() });
      return { flipped: true, match: false };
    }

    if (gameId === 'tic_tac_toe') {
      if (action !== 'move' || game.phase !== 'playing' || game.turnUid !== uid) {
        throw new HttpsError('failed-precondition', 'No es tu turno.');
      }
      const index = payload.index;
      const board = Array.isArray(game.board) ? [...game.board] : Array(9).fill('');
      if (!Number.isInteger(index) || index < 0 || index >= 9 || board[index]) {
        throw new HttpsError('invalid-argument', 'Casilla inválida.');
      }
      const symbol = game.symbols?.[uid];
      if (symbol !== 'X' && symbol !== 'O') throw new HttpsError('permission-denied', 'Jugador inválido.');
      board[index] = symbol;
      const winnerSymbol = ticTacToeWinner(board);
      const complete = Boolean(winnerSymbol) || board.every(Boolean);
      const winnerUid = winnerSymbol ? players.find((id) => game.symbols?.[id] === winnerSymbol) || '' : '';
      const nextUid = players.find((id) => id !== uid) || uid;
      tx.update(gameRef, { board, winnerUid, turnUid: complete ? '' : nextUid, phase: complete ? 'complete' : 'playing', updatedAt: FieldValue.serverTimestamp() });
      const rewardAwarded = Boolean(winnerUid) && rewardMiniGame(tx, coupleRef, claimRef, claimSnapshot, couple, gameId, winnerUid);
      return { moved: true, complete, winnerUid, rewardAwarded };
    }

    if (gameId === 'rock_paper_scissors') {
      if (action !== 'choose' || game.phase !== 'choosing') throw new HttpsError('failed-precondition', 'La ronda terminó.');
      const choice = payload.choice;
      if (!['rock', 'paper', 'scissors'].includes(choice)) throw new HttpsError('invalid-argument', 'Elección inválida.');
      const choices = { ...(privateState.choices || {}) };
      if (choices[uid]) throw new HttpsError('already-exists', 'Ya elegiste en esta ronda.');
      choices[uid] = choice;
      const submittedBy = Object.keys(choices).filter((id) => players.includes(id));
      const complete = players.length === 2 && players.every((id) => submittedBy.includes(id));
      let winnerUid = '';
      if (complete) {
        const result = rpsWinner(choices[players[0]], choices[players[1]]);
        winnerUid = result === 'first' ? players[0] : result === 'second' ? players[1] : '';
      }
      tx.update(privateRef, { choices, updatedAt: FieldValue.serverTimestamp() });
      tx.update(gameRef, { submittedBy, choices: complete ? choices : {}, winnerUid, phase: complete ? 'complete' : 'choosing', updatedAt: FieldValue.serverTimestamp() });
      const rewardAwarded = Boolean(winnerUid) && rewardMiniGame(tx, coupleRef, claimRef, claimSnapshot, couple, gameId, winnerUid);
      return { accepted: true, complete, winnerUid, rewardAwarded };
    }

    if (gameId === 'movie_guess') {
      if (action !== 'guess' || game.phase !== 'guessing') throw new HttpsError('failed-precondition', 'La ronda terminó.');
      const guess = typeof payload.guess === 'string' ? payload.guess.trim() : '';
      if (!guess || guess.length > 100) throw new HttpsError('invalid-argument', 'Respuesta inválida.');
      const correct = normalizeAnswer(guess) === normalizeAnswer(privateState.answer);
      const attempts = number(game.attempts) + 1;
      tx.update(gameRef, {
        attempts,
        phase: correct ? 'complete' : 'guessing',
        answer: correct ? privateState.answer : FieldValue.delete(),
        solvedBy: correct ? uid : FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      const rewardAwarded = correct && rewardMiniGame(tx, coupleRef, claimRef, claimSnapshot, couple, gameId, uid);
      return { correct, attempts, rewardAwarded };
    }

    throw new HttpsError('invalid-argument', 'Jugada no soportada.');
  });
}

exports.notifyCoupleActivity = onDocumentCreated('couples/{coupleCode}/chat/{messageId}', notifyCoupleActivityHandler);
exports.cleanupSharedPhoto = onDocumentDeleted('couples/{coupleCode}/chat/{messageId}', cleanupSharedPhotoHandler);
exports.createCoupleCode = onCall(createCoupleCodeHandler);
exports.cancelCoupleInvitation = onCall(cancelCoupleInvitationHandler);
exports.joinCouple = onCall(joinCoupleHandler);
exports.unlinkCouple = onCall(unlinkCoupleHandler);
exports.repairCoupleMembership = onCall(repairCoupleMembershipHandler);
exports.refreshCoupleProfiles = onCall(refreshCoupleProfilesHandler);
exports.setCouplePresence = onCall(setCouplePresenceHandler);
exports.sendChatMessage = onCall(sendChatMessageHandler);
exports.finalizePhotoMessage = onCall(finalizePhotoMessageHandler);
exports.discardPhotoUpload = onCall(discardPhotoUploadHandler);
exports.deleteChatMessage = onCall(deleteChatMessageHandler);
exports.markChatRead = onCall(markChatReadHandler);
exports.cleanupExpiredCoupleInvitations = onSchedule(
  'every 60 minutes',
  cleanupExpiredCoupleInvitationsHandler,
);
exports.performCoupleAction = onCall(performCoupleActionHandler);
exports.purchaseItem = onCall(purchaseItemHandler);
exports.claimDailyReward = onCall(claimDailyRewardHandler);
exports.saveSharedLayout = onCall(saveSharedLayoutHandler);
exports.equipHouse = onCall(equipHouseHandler);
exports.saveWellnessSettings = onCall(saveWellnessSettingsHandler);
exports.saveWellnessEntry = onCall(saveWellnessEntryHandler);
exports.deleteWellnessEntry = onCall(deleteWellnessEntryHandler);
exports.deleteWellnessData = onCall(deleteWellnessDataHandler);
exports.startLocationSharing = onCall(startLocationSharingHandler);
exports.updateSharedLocation = onCall(updateSharedLocationHandler);
exports.stopLocationSharing = onCall(stopLocationSharingHandler);
exports.cleanupExpiredLocationShares = onSchedule(
  'every 15 minutes',
  cleanupExpiredLocationSharesHandler,
);
exports.joinLudo = onCall(joinLudoHandler);
exports.rollLudoDice = onCall(rollLudoDiceHandler);
exports.moveLudoToken = onCall(moveLudoTokenHandler);
exports.resetLudo = onCall(resetLudoHandler);
exports.abandonLudo = onCall(abandonLudoHandler);
exports.openMiniGame = onCall(openMiniGameHandler);
exports.playMiniGame = onCall(playMiniGameHandler);

// Export handlers for emulator-backed unit tests without bypassing validation.
exports._test = {
  performCoupleActionHandler,
  purchaseItemHandler,
  claimDailyRewardHandler,
  saveSharedLayoutHandler,
  equipHouseHandler,
  saveWellnessSettingsHandler,
  saveWellnessEntryHandler,
  deleteWellnessEntryHandler,
  deleteWellnessDataHandler,
  startLocationSharingHandler,
  updateSharedLocationHandler,
  stopLocationSharingHandler,
  cleanupExpiredLocationSharesHandler,
  createCoupleCodeHandler,
  cancelCoupleInvitationHandler,
  joinCoupleHandler,
  unlinkCoupleHandler,
  repairCoupleMembershipHandler,
  refreshCoupleProfilesHandler,
  setCouplePresenceHandler,
  sendChatMessageHandler,
  finalizePhotoMessageHandler,
  discardPhotoUploadHandler,
  deleteChatMessageHandler,
  markChatReadHandler,
  notifyCoupleActivityHandler,
  cleanupExpiredCoupleInvitationsHandler,
  joinLudoHandler,
  rollLudoDiceHandler,
  moveLudoTokenHandler,
  resetLudoHandler,
  abandonLudoHandler,
  openMiniGameHandler,
  playMiniGameHandler,
  cleanupSharedPhotoHandler,
};
