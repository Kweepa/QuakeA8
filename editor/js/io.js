const HANDLE_DB = "quake64-editor";
const HANDLE_STORE = "handles";
const SHAREWARE_KEY = "shareware";
const SOUND_BANK_KEY = "sound-banks";
const WEAPONS_PNG_KEY = "weapons-png";
const REPO_KEY = "repo";
// Project root. The old "doc" file handle is left unread so a Quake64 path cannot be restored.
const PROJECT_KEY = "quakea8-project";
const PROJECT_DOC_REL = "editor/quake64.json";

export const DEFAULT_DOC_PATH = "quake64.json";

/** @type {FileSystemFileHandle | null} */
let docFileHandle = null;
/** @type {FileSystemDirectoryHandle | null} */
let projectDirHandle = null;
/** @type {FileSystemDirectoryHandle | null} */
let sharewareDirHandle = null;
/** @type {FileSystemDirectoryHandle | null} */
let weaponsPngDirHandle = null;
/** @type {FileSystemDirectoryHandle | null} */
let repoDirHandle = null;

export function docFileName() {
  return docFileHandle?.name || DEFAULT_DOC_PATH;
}

export function hasDocFileHandle() {
  return !!docFileHandle;
}

const EDITOR_SETTINGS_KEY = "quake64-editor-settings";

function isFlatEditorState(obj) {
  return !!obj && typeof obj === "object" && (obj.layoutCamera || obj.mode || obj.animOrbit);
}

export function loadEditorSettings(fileName) {
  try {
    const raw = localStorage.getItem(EDITOR_SETTINGS_KEY);
    if (!raw) return null;
    const all = JSON.parse(raw);
    if (!all || typeof all !== "object") return null;
    if (isFlatEditorState(all)) return all;
    const name = fileName || DEFAULT_DOC_PATH;
    return all[name] || null;
  } catch {
    return null;
  }
}

export function saveEditorSettings(fileName, state) {
  try {
    const name = fileName || DEFAULT_DOC_PATH;
    let all = {};
    try {
      all = JSON.parse(localStorage.getItem(EDITOR_SETTINGS_KEY) || "{}") || {};
    } catch {
      all = {};
    }
    if (isFlatEditorState(all)) all = { [name]: all };
    all[name] = state;
    localStorage.setItem(EDITOR_SETTINGS_KEY, JSON.stringify(all));
  } catch {
    /* private mode / quota */
  }
}

function openHandleDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(HANDLE_DB, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(HANDLE_STORE)) {
        db.createObjectStore(HANDLE_STORE);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function queryPermission(handle, mode = "readwrite") {
  if (!handle?.queryPermission) return "granted";
  return handle.queryPermission({ mode });
}

async function ensurePermission(handle, mode = "readwrite") {
  if (!handle?.queryPermission || !handle?.requestPermission) return true;
  const opts = { mode };
  if ((await handle.queryPermission(opts)) === "granted") return true;
  return (await handle.requestPermission(opts)) === "granted";
}

function withoutEditor(doc) {
  if (!doc || typeof doc !== "object") return doc;
  const { editor: _editor, ...rest } = doc;
  return rest;
}

async function writeDocToHandle(handle, doc) {
  const text = JSON.stringify(withoutEditor(doc), null, 2);
  const writable = await handle.createWritable();
  await writable.write(text);
  await writable.close();
}

async function readDocFromHandle(handle) {
  const file = await handle.getFile();
  return JSON.parse(await file.text());
}

async function projectDocFile(dir) {
  const marker = await getFileInDir(dir, "build-a8.bat");
  if (!marker) {
    throw new Error("That folder is not the QuakeA8 project (no build-a8.bat).");
  }
  const file = await getFileInDir(dir, PROJECT_DOC_REL);
  if (!file) {
    throw new Error(`${PROJECT_DOC_REL} is missing from that folder.`);
  }
  return file;
}

async function bindProjectDir(dir) {
  const file = await projectDocFile(dir);
  projectDirHandle = dir;
  docFileHandle = file;
  await storeHandle(PROJECT_KEY, dir);
  return file;
}

async function writeProjectDoc(doc) {
  if (!docFileHandle || !projectDirHandle) return null;
  if (!(await ensurePermission(projectDirHandle, "readwrite"))) {
    throw new Error("No write permission for the QuakeA8 folder");
  }
  await writeDocToHandle(docFileHandle, doc);
  return "file";
}

export async function getStoredProjectDir() {
  return loadStoredHandle(PROJECT_KEY);
}

export async function tryRestoreProjectDoc() {
  const dir = await loadStoredHandle(PROJECT_KEY);
  if (!dir) return null;
  if ((await queryPermission(dir, "readwrite")) !== "granted") return null;
  try {
    const file = await bindProjectDir(dir);
    return readDocFromHandle(file);
  } catch {
    projectDirHandle = null;
    docFileHandle = null;
    return null;
  }
}

export async function allowStoredProjectDir(dir) {
  if (!dir) return null;
  if (!(await ensurePermission(dir, "readwrite"))) return null;
  const file = await bindProjectDir(dir);
  return readDocFromHandle(file);
}

export async function pickProjectDirectory() {
  if (!window.showDirectoryPicker) {
    throw new Error("This browser cannot open a folder (needs Chromium file access)");
  }
  try {
    const opts = { id: "quakea8-project", mode: "readwrite" };
    const startIn = projectDirHandle || (await loadStoredHandle(PROJECT_KEY));
    if (startIn) opts.startIn = startIn;
    const handle = await window.showDirectoryPicker(opts);
    const file = await bindProjectDir(handle);
    return readDocFromHandle(file);
  } catch (e) {
    if (e.name === "AbortError") return null;
    throw e;
  }
}

/** Re-read editor/quake64.json. Null when the QuakeA8 folder is not granted yet. */
export async function loadProjectDoc() {
  if (!projectDirHandle) return tryRestoreProjectDoc();
  if (!(await ensurePermission(projectDirHandle, "readwrite"))) {
    throw new Error("No write permission for the QuakeA8 folder");
  }
  const file = await projectDocFile(projectDirHandle);
  docFileHandle = file;
  return readDocFromHandle(file);
}

export async function autosaveDocJSON(doc) {
  const how = await writeProjectDoc(doc);
  if (!how) {
    throw new Error("Open the QuakeA8 folder once so autosave can write editor/quake64.json");
  }
  return how;
}

export async function saveDocJSON(doc) {
  return writeProjectDoc(doc);
}

export function sharewareFolderName() {
  return sharewareDirHandle?.name || "";
}

export function hasSharewareDirHandle() {
  return !!sharewareDirHandle;
}

async function storeHandle(key, handle) {
  if (!window.indexedDB || !handle) return;
  const db = await openHandleDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction(HANDLE_STORE, "readwrite");
    tx.objectStore(HANDLE_STORE).put(handle, key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

async function loadStoredHandle(key) {
  if (!window.indexedDB) return null;
  try {
    const db = await openHandleDb();
    const handle = await new Promise((resolve, reject) => {
      const tx = db.transaction(HANDLE_STORE, "readonly");
      const req = tx.objectStore(HANDLE_STORE).get(key);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => reject(req.error);
    });
    db.close();
    return handle || null;
  } catch {
    return null;
  }
}

async function storeSharewareHandle(handle) {
  sharewareDirHandle = handle;
  await storeHandle(SHAREWARE_KEY, handle);
}

export async function getStoredSharewareHandle() {
  return loadStoredHandle(SHAREWARE_KEY);
}

export async function tryRestoreSharewareDir() {
  const handle = await loadStoredHandle(SHAREWARE_KEY);
  if (!handle) return null;
  const state = await queryPermission(handle, "read");
  if (state !== "granted") return null;
  sharewareDirHandle = handle;
  return handle;
}

export async function allowStoredSharewareDir(handle) {
  if (!handle) return null;
  if (!(await ensurePermission(handle, "read"))) return null;
  await storeSharewareHandle(handle);
  return handle;
}

export function repoFolderName() {
  return repoDirHandle?.name || "";
}

export async function tryRestoreRepoDir() {
  const handle = await loadStoredHandle(REPO_KEY);
  if (!handle) return null;
  const state = await queryPermission(handle, "read");
  if (state !== "granted") return null;
  repoDirHandle = handle;
  return handle;
}

export async function pickRepoDirectory() {
  if (!window.showDirectoryPicker) {
    throw new Error("This browser cannot open a folder (needs Chromium file access)");
  }
  try {
    const opts = { id: "quake64-repo", mode: "read" };
    const startIn = repoDirHandle || (await loadStoredHandle(REPO_KEY));
    if (startIn) opts.startIn = startIn;
    const handle = await window.showDirectoryPicker(opts);
    repoDirHandle = handle;
    await storeHandle(REPO_KEY, handle);
    return handle;
  } catch (e) {
    if (e.name === "AbortError") return null;
    throw e;
  }
}

/** Text of a file in the repo root, or null if it is not there. */
export async function readRepoFile(dirHandle, name) {
  if (!(await ensurePermission(dirHandle, "read"))) {
    throw new Error("No read permission for the repo folder");
  }
  const fh = await getFileInDir(dirHandle, name);
  if (!fh) return null;
  return (await fh.getFile()).text();
}

export async function pickSharewareDirectory() {
  if (!window.showDirectoryPicker) {
    throw new Error("This browser cannot open a folder (needs Chromium file access)");
  }
  try {
    const handle = await window.showDirectoryPicker({
      id: "quake-shareware",
      mode: "read",
    });
    await storeSharewareHandle(handle);
    return handle;
  } catch (e) {
    if (e.name === "AbortError") return null;
    throw e;
  }
}

async function getFileInDir(dir, relPath) {
  const parts = relPath.split("/");
  let cur = dir;
  for (let i = 0; i < parts.length - 1; i++) {
    try {
      cur = await cur.getDirectoryHandle(parts[i]);
    } catch {
      return null;
    }
  }
  try {
    return await cur.getFileHandle(parts[parts.length - 1]);
  } catch {
    return null;
  }
}

export async function tryRestoreSoundBankDir() {
  const handle = await loadStoredHandle(SOUND_BANK_KEY);
  if (!handle) return null;
  const state = await queryPermission(handle, "read");
  if (state !== "granted") return null;
  return handle;
}

export async function pickSoundBankDirectory() {
  if (!window.showDirectoryPicker) {
    throw new Error("This browser cannot open a folder (needs Chromium file access)");
  }
  try {
    const handle = await window.showDirectoryPicker({
      id: "quake-sound-banks",
      mode: "read",
    });
    await storeHandle(SOUND_BANK_KEY, handle);
    return handle;
  } catch (e) {
    if (e.name === "AbortError") return null;
    throw e;
  }
}

const SOUND_BANK_FILES = ["AUDIOHED.WL1", "AUDIOT.WL1", "DOOM.WAD", "DAVE.EXE", "SOUNDS.CK1"];

/** Read the five ref/ banks from the picked folder or its ref/ child. */
export async function loadSoundBankBuffers(dirHandle) {
  const roots = [dirHandle];
  try {
    roots.push(await dirHandle.getDirectoryHandle("ref"));
  } catch {
    /* the folder may already be ref/ */
  }
  const out = {};
  for (const name of SOUND_BANK_FILES) {
    for (const root of roots) {
      const fh = await getFileInDir(root, name);
      if (!fh) continue;
      out[name] = await (await fh.getFile()).arrayBuffer();
      break;
    }
  }
  return out;
}

/** Load pak0 then pak1 from the folder or an id1/ child. */
export async function loadSharewarePakBuffers(dirHandle) {
  const buffers = [];
  const seen = new Set();
  const candidates = ["pak0.pak", "id1/pak0.pak", "pak1.pak", "id1/pak1.pak"];
  for (const rel of candidates) {
    const fh = await getFileInDir(dirHandle, rel);
    if (!fh) continue;
    const file = await fh.getFile();
    const key = `${file.name}:${file.size}:${file.lastModified}`;
    if (seen.has(key)) continue;
    seen.add(key);
    buffers.push(await file.arrayBuffer());
  }
  return buffers;
}

export async function ensureWeaponsPngDirectory() {
  if (weaponsPngDirHandle && (await ensurePermission(weaponsPngDirHandle, "readwrite"))) {
    return weaponsPngDirHandle;
  }
  const stored = await loadStoredHandle(WEAPONS_PNG_KEY);
  if (stored && (await ensurePermission(stored, "readwrite"))) {
    weaponsPngDirHandle = stored;
    return stored;
  }
  return pickWeaponsPngDirectory();
}

export async function pickWeaponsPngDirectory() {
  if (!window.showDirectoryPicker) {
    throw new Error("This browser cannot open a folder (needs Chromium file access)");
  }
  try {
    const opts = { id: "quake-assets-weapons", mode: "readwrite" };
    const startIn = weaponsPngDirHandle || (await loadStoredHandle(WEAPONS_PNG_KEY));
    if (startIn) opts.startIn = startIn;
    const handle = await window.showDirectoryPicker(opts);
    weaponsPngDirHandle = handle;
    await storeHandle(WEAPONS_PNG_KEY, handle);
    return handle;
  } catch (e) {
    if (e.name === "AbortError") return null;
    throw e;
  }
}

export async function writePngFile(dirHandle, filename, blob) {
  const fh = await dirHandle.getFileHandle(filename, { create: true });
  const writable = await fh.createWritable();
  await writable.write(blob);
  await writable.close();
}

export function downloadJSON(doc, filename = DEFAULT_DOC_PATH) {
  const blob = new Blob([JSON.stringify(withoutEditor(doc), null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
