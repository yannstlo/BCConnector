# BCConnector

BCConnector is a SwiftUI application that connects to Microsoft Dynamics 365 Business Central, allowing users to view and manage customers, vendors, and orders.

## Features

- Authentication with Microsoft Azure AD
- View and manage customers
- View and manage vendors
- View orders
- Interactive map view for customer and vendor addresses

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Microsoft Dynamics 365 Business Central account

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/BCConnector.git
   ```
2. Open the project in Xcode:
   ```
   cd BCConnector
   open BCConnector.xcodeproj
   ```
3. Build and run the project in Xcode.

## Configuration

Before running the app, you need to configure your Business Central settings:

1. Open the app and go to the Settings tab.
2. Enter your Business Central credentials:
   - Client ID
   - Client Secret
   - Tenant ID
   - Company ID
   - Environment
   - Redirect URI

## Usage

1. Launch the app and log in with your Business Central credentials.
2. Navigate through the tabs to view customers, vendors, and orders.
3. Tap on a customer or vendor to view details and see their location on a map.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
