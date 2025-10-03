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

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure Firebase**

   - Create a Firebase project.
   - Add your Android/iOS app.
   - Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS).
   - Place them in the appropriate directories.

4. **Run the app**

   ```bash
   flutter run
   ```

---

## 📱 Usage

- Open the app and sign in with your account.
- Upload a photo of a trash bin to check its fullness status.
- View real-time waste data from your subdivision.
- Administrators can use insights to plan efficient collection schedules.

---

## 🔮 Future Enhancements

- AI-powered image recognition improvements.
- Integration with IoT smart bins for direct monitoring.
- Data visualization dashboards for administrators.
- Multi-language support for wider adoption.

---

## 👥 Contributors

- **Daradal, Dowell Nathan** – Developer / Researcher
- **Francisco, Rafaelle** – Developer / Researcher
- **Gutierrez, Vincent Marcial** – Developer / Researcher
- **Salazar, Rhaniel Xander** – Developer / Researcher
- Adviser: Aileen Vasquez
- Institution: Siena College of Taytay

---

## 📜 License

This project is developed as part of an academic thesis.
Usage and distribution rights may vary depending on institutional policies.
