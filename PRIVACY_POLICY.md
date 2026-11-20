# Privacy Policy for Epilogue

**Last Updated:** November 20, 2026

Epilogue ("we", "our", or "the app") is an open-source, local-first electronic book and novel reader. We respect your privacy and are committed to protecting it. This Privacy Policy outlines our handling of your data.

---

## 1. Zero Personal Data Collection
- **Local-First Architecture:** Epilogue operates locally on your device. Your reading library, reading progress, highlights, annotations, reading statistics, and settings are stored directly on your device storage.
- **No Analytics or Tracking:** Epilogue contains no telemetry, user tracking, advertisements, or third-party analytics SDKs. We do not operate external tracking servers, and we never collect, monetize, or sell your personal information.

---

## 2. Google Drive Cloud Sync & Google User Data

Epilogue offers an optional Cloud Backup & Sync feature powered by Google Drive. Using this feature requires signing in with your Google account.

### A. Scopes Requested
When you sign in, Epilogue requests permission for the following non-sensitive scope:
- **`https://www.googleapis.com/auth/drive.file`** (Per-file access)

### B. How We Use Google Drive
- **Isolated Storage:** Under this scope, Epilogue can **only** access, create, edit, or delete files and folders created specifically by Epilogue (within the `Epilogue Cloud Backup` directory).
- **No Access to Other Files:** Epilogue has **no access** to your personal files, photos, documents, or any other items stored in your Google Drive.
- **Purpose of Use:** Epilogue uses this access solely to:
  1. Upload your reading metadata (`epilogue_backup.json`).
  2. Upload your EPUB library files to your own Google Drive so you can sync them across devices.
  3. Download your backups to restore your library on a new or secondary device.

### C. Data Sharing & Third Parties
- **No Third-Party Transmission:** Your Google credentials and backup files are transferred directly and securely between your device and Google's official Drive API endpoints over HTTPS.
- We do not transmit, copy, or store your Google account data or backups on any intermediary servers or third-party services.
- We do not share, sell, or use your Google Drive data for advertising or marketing.

### D. Google API Limited Use Disclosure
Epilogue's use and transfer to any other app of information received from Google APIs will adhere to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

---

## 3. Data Retention and Deletion

You retain full control over your data at all times:
- **Local Data:** You can delete all local data at any time by clearing the app data or uninstalling Epilogue from your device.
- **Cloud Data:** You can permanently delete your cloud backups at any time by:
  1. Deleting the `Epilogue Cloud Backup` folder directly inside your [Google Drive](https://drive.google.com/).
  2. Revoking Epilogue's access to your Google account at [Google Account Security Settings](https://myaccount.google.com/permissions).

---

## 4. Open Source Transparency

Epilogue is free, libre, and open-source software. You can inspect the complete source code, including the implementation of the Google Drive sync service, on our GitHub repository:
[https://github.com/EtherealInsanity/Epilogue](https://github.com/EtherealInsanity/Epilogue)

---

## 5. Contact & Questions

If you have any questions, feedback, or concerns regarding this Privacy Policy or Epilogue's privacy practices, please open an issue on our GitHub repository:
[https://github.com/EtherealInsanity/Epilogue/issues](https://github.com/EtherealInsanity/Epilogue/issues)
