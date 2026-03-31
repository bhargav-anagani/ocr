# OcrVision — Full-Stack OCR Application

A production-ready OCR application with a **Python FastAPI** backend and **Flutter** frontend (runs on both **Android** and **Web**).

---

## 🗂 Project Structure

```
OCR/
├── backend/          # Python FastAPI + Tesseract OCR
└── flutter_app/      # Flutter (Android + Web)
```

---

## ✅ Prerequisites

Before you begin, install:

| Tool | Version | Notes |
|------|---------|-------|
| Python | 3.9+ | [python.org](https://python.org) |
| Tesseract OCR | 5.x | **Windows**: [UB-Mannheim installer](https://github.com/UB-Mannheim/tesseract/wiki) |
| MongoDB | 6.x | [MongoDB Community](https://www.mongodb.com/try/download/community) or use [Atlas](https://cloud.mongodb.com) |
| Flutter SDK | 3.19+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Android Studio | Latest | For Android emulator / device |

---

## 🔧 Backend Setup

### 1. Install Python dependencies

```powershell
cd OCR/backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

> **OpenCV note**: `opencv-python-headless` is used (no GUI) to avoid display issues on servers.

### 2. Configure environment

```powershell
copy .env.example .env
```

Edit `.env` and set:

```env
MONGODB_URL=mongodb://localhost:27017
DATABASE_NAME=ocr_app
SECRET_KEY=your-random-secret-key-here   # generate with: python -c "import secrets; print(secrets.token_hex(32))"
TESSERACT_CMD=C:\Program Files\Tesseract-OCR\tesseract.exe
```

> **Linux/Mac**: Tesseract is usually auto-detected. Leave `TESSERACT_CMD` blank or set to `/usr/bin/tesseract`.

### 3. Verify Tesseract installation

```powershell
tesseract --version
```

Should print: `tesseract 5.x.x`

### 4. Start MongoDB

Make sure MongoDB is running locally:
```powershell
# If installed as a service, it may already be running
# Or run: mongod --dbpath C:\data\db
```

### 5. Start the backend

```powershell
# From OCR/backend directory, with venv activated
uvicorn app.main:app --reload --port 8000
```

**Test it:**
- Health check: http://localhost:8000/health
- Swagger UI: http://localhost:8000/docs

---

## 📱 Flutter App Setup

### 1. Install dependencies

```powershell
cd OCR/flutter_app
flutter pub get
```

### 2. Configure backend URL

Edit `lib/core/constants/app_constants.dart`:

```dart
static const String baseUrl = 'http://localhost:8000';  // Change for production
```

> **Android emulator**: Use `http://10.0.2.2:8000` instead of `localhost`.  
> **Physical Android device**: Use your machine's local IP, e.g. `http://192.168.1.x:8000`.

### 3. Create asset directories

```powershell
New-Item -ItemType Directory -Path flutter_app/assets/images -Force
New-Item -ItemType Directory -Path flutter_app/assets/animations -Force
```

### 4. Run on Web

```powershell
flutter run -d chrome
```

### 5. Run on Android

```powershell
# List available devices
flutter devices

# Run on connected device or emulator
flutter run -d <device-id>
```

### 6. Build for release

```powershell
# Android APK
flutter build apk --release

# Web
flutter build web --release
```

---

## 🌐 API Reference

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health` | — | Server health check |
| POST | `/api/auth/register` | — | Register new user |
| POST | `/api/auth/login` | — | Login → JWT token |
| POST | `/api/ocr/upload` | 🔒 JWT | Upload file → OCR text |
| GET | `/api/ocr/history` | 🔒 JWT | Paginated history |
| GET | `/api/ocr/{id}` | 🔒 JWT | Get specific result |
| GET | `/api/ocr/download/{id}` | 🔒 JWT | Download as .txt |
| DELETE | `/api/ocr/{id}` | 🔒 JWT | Delete result |
| GET | `/api/ocr/stats/summary` | 🔒 JWT | Usage statistics |

---

## 🚀 Deployment

### Backend — Render / Railway / VPS

1. **Set environment variables** in your cloud dashboard (same as `.env`)
2. **Install Tesseract** on the server:
   ```bash
   # Ubuntu/Debian
   apt-get install -y tesseract-ocr
   ```
3. **Start command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. **Database**: Use [MongoDB Atlas](https://cloud.mongodb.com) free tier and set `MONGODB_URL` to the Atlas connection string

### Flutter Web — Vercel / Firebase Hosting / Netlify

```powershell
# Build web
flutter build web --release

# Deploy built files from flutter_app/build/web/
```

For Vercel:
```powershell
npx vercel flutter_app/build/web
```

### Android — Google Play Store

```powershell
flutter build appbundle --release
```
Upload the `.aab` from `build/app/outputs/bundle/release/` to Google Play Console.

> Remember to update `AppConstants.baseUrl` to your production backend URL before building for release.

---

## 🧠 OCR Processing Pipeline

```
1. File upload (JPG/PNG/PDF)
   ↓
2. OpenCV Preprocessing
   • Grayscale conversion
   • Noise removal (fastNlMeansDenoising)
   • Adaptive thresholding
   • Deskewing
   ↓
3. Tesseract OCR
   • OEM 3 (LSTM + Legacy)
   • PSM 6 (Uniform text block)
   • Confidence-per-word scoring
   ↓
4. PDF: Each page → rendered at 300 DPI → OCR per page
   ↓
5. Results stored in MongoDB
   • filename, extracted_text, confidence, word_count, timestamps
```

---

## 🔐 Security Notes

- JWT tokens expire after **24 hours**
- Passwords are hashed with **bcrypt**
- Uploaded files are processed **in-memory** (not stored on disk permanently)
- Set a strong `SECRET_KEY` in production (32+ random characters)
- In production, restrict `CORS_ORIGINS` in `.env` to your actual frontend URL

---

## 🐞 Troubleshooting

| Issue | Fix |
|-------|-----|
| `tesseract is not installed` | Set `TESSERACT_CMD` in `.env` to the full Tesseract path |
| `Connection refused` in Flutter | Backend not running, or wrong IP for Android (`10.0.2.2` for emulator) |
| `pymongo.errors.ServerSelectionTimeoutError` | MongoDB not running. Start `mongod` |
| `flutter pub get` fails | Run `flutter doctor` and fix any SDK issues |
| Low OCR confidence | Improve image quality: use 300+ DPI, ensure good lighting |

---

## 📦 Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| Backend Framework | FastAPI (Python) |
| OCR Engine | Tesseract OCR 5 |
| Image Preprocessing | OpenCV |
| PDF Processing | PyMuPDF (fitz) |
| Database | MongoDB + Motor (async) |
| Authentication | JWT (python-jose) + bcrypt |
| Mobile + Web Frontend | Flutter 3 |
| State Management | Riverpod |
| Navigation | go_router |
| HTTP Client | Dio |
| UI | Material 3 + Google Fonts (Inter) |
