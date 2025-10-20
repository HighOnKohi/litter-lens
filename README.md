# 🌱 Litter Lens (A.K.A. Eco Metrics)

_A Waste Monitoring and Analytics App for Subdivisions_

## 📖 Introduction

This study proposes the development of **Litter Lens: A Waste Monitoring and Analytics App for Subdivisions**, a mobile platform envisioned as a centralized digital hub that improves the flow of information between residents and subdivision administrators. The app is designed to make waste collection and community services more efficient, transparent, and data-driven.

A key feature of Litter Lens is its ability to automatically detect the status of trash bins through uploaded photos. Using a custom photo recognition API, the system can determine whether a bin is empty, half-full, or full, and record the information in real time. This innovation ensures that subdivision managers receive timely and consistent data on waste volume and location. With this information, management can make informed decisions on when and where to deploy collection teams, thereby optimizing routes, reducing unnecessary trips, and minimizing operational costs.

Beyond logistics, the app promotes stronger administrative participation and environmental responsibility. By offering a user-friendly interface, it empowers administrators to take an active role in maintaining cleanliness within their community. At the same time, the platform encourages sustainable practices such as waste segregation and fosters awareness of proper disposal methods among residents.

Ultimately, this project seeks to provide a framework for modern, sustainable, and community-centered waste monitoring. By integrating mobile technology with real-time data analytics, Litter Lens has the potential to transform subdivisions into cleaner, smarter, and more sustainable communities.

---

## ✨ Features

- 📸 **Photo Recognition of Trash Bins** – Upload images to automatically detect whether a bin is empty, half-full, or full.
- 🗂️ **Centralized Information Hub** – Streamlined communication between residents and subdivision administrators.
- 🚛 **Route Optimization Support** – Data-driven decision-making for collection scheduling and deployment.
- 🌍 **Community Awareness** – Encourages waste segregation and proper disposal practices.
- 👤 **User-Friendly Interface** – Accessible for both administrators and residents.

---

## 🏗️ Technology Stack

- **Frontend (Mobile App):** [Flutter](https://flutter.dev/) (Dart)
- **Backend & API:** Custom Python API for trash bin fullness detection
- **Database:** Firebase Firestore (for storing reports & user data)
- **Authentication:** Firebase Authentication
- **Storage:** Firebase Cloud Storage (for uploaded images)

---

## ⚙️ Installation

1. **Clone this repository**

   ```bash
   git clone https://github.com/your-username/Litter Lens.git
   cd Litter Lens
   ```

# 🌱 Litter Lens

This study proposes the development of a Waste Monitoring and Analytics System designed for residential subdivisions. The system consists of both a website and an Android application that work together to streamline waste monitoring and communication within the community.

The system serves as a centralized digital platform, enabling trash collectors to submit real-time data via voice commands through the Android app and allowing subdivision administrators to monitor and analyze this data via the web-based dashboard. At the same time, residents can use the Android app to view announcements, reminders, and updates related to waste collection and community programs.

A key feature of the proposed system is its voice-activated data submission. Trash collectors can verbally report information such as the location and how full the bin is through their Android devices. The system processes and stores these reports automatically, tagging them with the corresponding date, time, and subdivision.

Administrators have access to a web dashboard that provides real-time analytics, graphs of waste buildup, and a blueprint planner. With these tools, administrators can make informed decisions on optimizing garbage truck routes, identifying problem-prone areas, and assessing the effectiveness of waste programs.

Ultimately, this project seeks to modernize subdivision waste monitoring through integrated mobile and web technologies, combining voice-driven data input, analytics, and communication tools into one unified system. This innovation promotes cleaner, more efficient, and more sustainable community operations.

---

## What the app does (high level)

- Voice-driven data submission for quick field reporting by trash collectors.
- Android app for collectors and residents:
  - Collectors: submit reports via voice; attach photo evidence when needed.
  - Residents: view announcements, reminders, and locality updates from administrators.
- Web dashboard for administrators with real-time analytics, charts, and a blueprint planner to support route optimization and program evaluation.
- Stores timestamps and subdivision context alongside reports to support filtering and analytics.
- Provides a user-friendly interface for communication between collectors, residents, and administrators.

---

## Quick start (developer)

1. Install dependencies:

```bash
flutter pub get
```

2. Run the app (development):

```bash
flutter run
```

Notes: If you run into emulator camera or Google Play Services issues, try a physical device or a different emulator image.

---

## Contributors

- **Daradal, Dowell Nathan** – Developer / Researcher
- **Francisco, Rafaelle** – Developer / Researcher
- **Gutierrez, Vincent Marcial** – Developer / Researcher
- **Salazar, Rhaniel Xander** – Developer / Researcher
- Adviser: Aileen Vasquez
- Institution: Siena College of Taytay

---

## License / Attribution

This repository contains work for an academic thesis. Check project maintainers or your institution for licensing and distribution permissions.
