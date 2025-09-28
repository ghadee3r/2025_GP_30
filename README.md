# Rikaz | رِكَاز  

## Introduction  
**Rikaz** is a smart system designed to help students and professionals sustain focus and improve productivity during study or work sessions.  
The system integrates a **mobile Android application** with supportive **hardware tools** (smart light, external LCD timer screen, and camera).  

Rikaz assists users by:  
- Providing **structured focus sessions** (custom and Pomodoro modes).  
- Detecting distractions in real-time using **computer vision (OpenMV camera)**.  
- Delivering **adaptive feedback** (light cues, audio notifications).  
- Offering a **progress analysis dashboard** with daily, weekly, and monthly summaries.  
- Synchronizing with **Google Calendar** for session scheduling.  

Unlike traditional focus apps, Rikaz combines **AI-based distraction detection** with supportive hardware to create a productive and engaging environment.  

---

## Technology  
Rikaz uses a combination of software and hardware tools:  

**Software Stack**  
- **React Native** – Mobile application framework (JavaScript).  
- **TensorFlow / Roboflow** – Machine learning and computer vision.  
- **Google Calendar API** – Session scheduling and reminders.  
- **SQLite / Backend server** – Data storage and synchronization.  
- **Arduino IDE + WLED** – Hardware programming and LED control.  
- **GitHub** – Version control and collaboration.  
- **Jira & Confluence** – Project management and documentation.  

**Hardware Components**  
- **ESP32 DevKitV1** – Microcontroller.  
- **OpenMV4 H7 Plus** – AI-based distraction detection camera.  
- **WS2812B Smart LED** – Adaptive lighting feedback.  
- **LCD Timer Screen** – Displays remaining focus session time.  

---

## Launching Instructions  

### Mobile Application  
1. Clone the repository:  
   ```bash
   git clone https://github.com/ghadee3r/2025_GP_30.git
   cd 2025_GP_30
   ```

2. Install dependencies:  
   ```bash 
   npm install
   ```

3. Run the application on Android:
   ```bash
   npx react-native run-android
   ```

(Ensure Android Studio and Android SDK are installed).


