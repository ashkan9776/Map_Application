# Map Navigator App

**Map Navigator App** is a state-of-the-art navigation and mapping application built with **Flutter**. It seamlessly integrates geolocation, real-time route navigation, and customizable map layers to provide a smooth and interactive user experience. The app is designed to be intuitive, fast, and efficient while offering several advanced features like location-based services, map style toggling, and a clean, modern UI.

## Features

- **Real-Time Location Tracking:** Tracks the user’s current location and provides navigation assistance.
- **Turn-by-Turn Directions:** Fetches directions between two points and gives real-time updates on the distance, estimated time of arrival (ETA), and step-by-step navigation.
- **Add Locations to Favorites:** Users can store frequently visited locations for quick access in the future.
- **Customizable Map Layers:** Toggle between different map styles such as terrain view, satellite view, and more.
- **Interactive Map:** With **flutter_map** and **latlong2**, the app allows the user to zoom, scroll, and interact with the map.

## Architecture & State Management

### **Architecture**

The app follows a **clean architecture** to ensure separation of concerns and maintainability. It follows a modular structure where each component (UI, data layer, and domain logic) is decoupled from one another, ensuring that changes in one module do not affect others. This modular approach provides the flexibility to extend the app with new features easily.

#### **Key Architectural Components:**

1. **UI Layer (Presentation Layer):**
   - The **UI layer** is built using **Flutter**'s powerful widget system, with a focus on a **responsive and adaptive design** to ensure a great experience on both phones and tablets.
   - **Riverpod** is used for state management to maintain a smooth, consistent user experience. Riverpod allows for **global state management** while maintaining an easy-to-manage, testable, and performant codebase.

2. **Domain Layer:**
   - The **domain layer** encapsulates the core business logic of the app, such as calculating distances, fetching routes, and managing user preferences (e.g., favorite locations).
   - **Services** and **UseCases** are defined here to interact with the **Data Layer** and provide the required functionality to the UI layer.

3. **Data Layer:**
   - This layer handles all data-related operations. It fetches data from external sources (e.g., APIs for directions, geolocation services) and local databases (e.g., SQLite for storing favorite locations).
   - **Sqflite** is used for local storage, allowing for efficient storage and retrieval of user data like favorite locations.
   - **Http** is used to fetch routing data, and **geolocator** helps track the user's location in real-time.
   
### **State Management with Riverpod**

The app uses **Riverpod** for **state management** due to its scalability and flexibility. Riverpod ensures that the state of the application is maintained across different widgets and pages. Here's a quick overview of how state is managed:

- **Global State:** Using Riverpod's **Provider** and **StateNotifierProvider**, we handle global app states such as user preferences, current location, and selected map layers. This ensures that the data is shared across different parts of the app and easily accessed without redundancy.
- **Navigation & Directions:** The state of the route (e.g., start, destination, polyline points) is managed via **StateNotifier** to provide real-time updates.
- **Favorite Locations:** The state of favorite locations is saved in a local database (SQLite) and managed through Riverpod's **StateNotifier** to ensure consistency and provide reactive updates when adding or removing locations.

### **Modern UI Design & User Experience**

The **Map Navigator App** uses a modern UI design approach, prioritizing both functionality and aesthetics:

- **Glassmorphism**: The app utilizes the **glassmorphism** package for a sleek, modern look with frosted glass-like effects on some UI elements.
- **Smooth Animations**: Transitions between pages and interactions are enhanced with **flutter_staggered_animations** and **lottie** animations to create a visually appealing and dynamic experience.
- **Responsive Layout**: The layout is fully responsive, adjusting seamlessly for both small and large screen devices, thanks to Flutter's powerful layout system.

## Dependencies

This app leverages several Flutter packages to streamline development and improve functionality:

- **flutter_map**: For displaying and interacting with maps.
- **geolocator**: To handle real-time geolocation and user location tracking.
- **sqflite**: A lightweight database for storing favorite locations locally.
- **flutter_riverpod**: Manages the app’s global state and ensures smooth navigation and data flow.
- **permission_handler**: Requests necessary permissions (e.g., location access).
- **flutter_polyline_points**: Generates routes and polylines between two locations.
- **animated_bottom_navigation_bar**: Provides a smooth and customizable bottom navigation bar.
- **lottie**: For adding rich animations to enhance the user experience.
- **flutter_tts**: Text-to-speech functionality to read out navigation directions.
- **connectivity_plus**: Checks network connectivity to ensure proper functioning when offline.
- **flutter_speed_dial**: Adds a floating action button with multiple options.
  
### Full List of Dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_map: ^8.2.2
  latlong2: ^0.9.1
  http: ^1.5.0
  geolocator: ^14.0.2
  permission_handler: ^12.0.1
  flutter_polyline_points: ^3.1.0
  glassmorphism: ^3.0.0
  animated_bottom_navigation_bar: ^1.4.0
  path: ^1.9.1
  sqflite: ^2.4.2
  connectivity_plus: ^7.0.0
  sliding_up_panel: ^2.0.0+1
  flutter_speed_dial: ^7.0.0
  flutter_staggered_animations: ^1.1.1
  lottie: ^3.3.2
  google_fonts: ^6.3.1
  flutter_tts: ^4.2.3
  shared_preferences: ^2.5.3
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0
  freezed_annotation: ^3.1.0
  riverpod: ^3.0.0
