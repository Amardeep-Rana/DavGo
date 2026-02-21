# DavGo 🚀

**DavGo** is a powerful and easy-to-use application that transforms your Android device into a local **WebDAV** or **FTP** server. With this app, you can access and manage your phone's files from a PC, laptop, or any browser using just WiFi or a Hotspot—no USB cable required.

## 🛠️ Built With
- **Flutter**: Built using Google's Flutter framework for a fast and responsive cross-platform experience.
- **Dart**: The core programming language.

## 📦 Important Libraries
The app leverages several key libraries to provide a seamless experience:
- **`shelf` & `shelf_io`**: Used for hosting the WebDAV and HTTP server.
- **`ftp_server`**: Provides robust FTP protocol support.
- **`connectivity_plus` & `network_info_plus`**: Detects network status and retrieves the device's local IP address.
- **`permission_handler`**: Manages essential storage and network permissions.
- **`wakelock_plus`**: Keeps the screen awake while the server is running to prevent connection drops.
- **`path`**: Handles complex file system paths across the device.

## 🔐 Permissions & Requirements
To function correctly, DavGo requires the following permissions:
1. **INTERNET**: To host the server on your local network and facilitate data transfer.
2. **ACCESS_WIFI_STATE / ACCESS_NETWORK_STATE**: To check connectivity and identify the server's IP address.
3. **MANAGE_EXTERNAL_STORAGE**: Required on Android 11+ to access all files for sharing.
4. **READ/WRITE_EXTERNAL_STORAGE**: Required on older Android versions to read and modify files.

> **Note**: Storage permissions are critical because DavGo is a file server application; it cannot share or manage files without this access.

## ✨ Features
- **Dual Protocol Support**: Choose between **WebDAV** or **FTP** server types based on your needs.
- **Customizable Root Folder**: Share your entire storage or select a specific folder to limit access.
- **Security Options**:
    - Password protection (Toggleable).
    - Support for custom Usernames and Ports.
    - **Read-Only Mode**: Allow others to view files without the ability to delete or modify them.
- **Hidden Files Toggle**: Easily show or hide system files (dotfiles).
- **Wake Lock**: Prevents the screen from turning off while the server is active, ensuring a stable connection.
- **Auto-Password**: Generates a new random password every time the service starts for enhanced security.

## 🎨 UI/UX Design
- **Modern & Clean UI**: A simple yet attractive interface following modern Material Design principles.
- **Dark/Light Mode**: Full support for both **Dark** and **Light** themes, easily toggleable from the app bar.
- **Interactive Animations**: Smooth slide animations when switching server types and polished loading transitions.
- **One-Click Start**: A streamlined user journey—just one tap to get your server running.

## 🚀 How to Use
1. Open the app and ensure you are connected to a WiFi network or have a Hotspot active.
2. Select your preferred server type (**WebDAV** or **FTP**).
3. Tap the **"Start Service"** button.
4. Enter the displayed IP address and Port (e.g., `http://192.168.1.5:8080`) into your PC's File Explorer or web browser.

---
**Developed by:** [@LegendAmardeep](https://github.com/Amardeep-Rana) ❤️
