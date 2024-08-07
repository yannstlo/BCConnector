# BCConnector iOS App

BCConnector is a powerful SwiftUI application that seamlessly integrates with Microsoft Dynamics 365 Business Central, providing users with a user-friendly interface to view and manage customers, vendors, and orders on iOS devices.

<p align="center">
  <img src="screenshot1.png" width="200" alt="BCConnector Screenshot 1">
  <img src="screenshot2.png" width="200" alt="BCConnector Screenshot 2">
  <img src="screenshot3.png" width="200" alt="BCConnector Screenshot 3">
  <img src="screenshot4.png" width="200" alt="BCConnector Screenshot 4">
</p>

## Features

- **Secure Authentication**: Utilizes Microsoft Azure AD for robust and secure user authentication.
- **Customer Management**: 
  - View a comprehensive list of customers
  - Access detailed customer information including contact details, financial data, and sales information
  - Visualize customer locations on an interactive map
- **Vendor Management**:
  - Browse through the list of vendors
  - View detailed vendor information including contact details and financial data
  - Locate vendors on an interactive map
- **Order Tracking**: 
  - Access and view order information directly from Business Central
  - See order details including customer name, order date, and total amount
- **Interactive Map Integration**: Visualize customer and vendor addresses on an interactive map for better geographical context.
- **Settings Management**: Easily configure and manage Business Central connection settings within the app.
- **Offline Support**: Basic functionality available offline with data caching (coming soon).

## Requirements

- iOS 15.0 or later
- Xcode 13.0 or later
- Swift 5.5 or later
- Active Microsoft Dynamics 365 Business Central account

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/BCConnector.git
   ```
2. Navigate to the project directory:
   ```
   cd BCConnector
   ```
3. Open the project in Xcode:
   ```
   open BCConnector.xcodeproj
   ```
4. Build and run the project in Xcode.

## Configuration

Before using the app, you need to configure your Business Central settings:

1. Launch the app and navigate to the Settings tab.
2. Enter your Business Central credentials:
   - Client ID
   - Client Secret
   - Tenant ID
   - Company ID
   - Environment
   - Redirect URI

Ensure all fields are filled correctly for the app to function properly.

## Usage

1. Launch the app and log in using your Microsoft account associated with Business Central.
2. Once authenticated, you'll have access to the main features:
   - **Customers**: View customer list, access detailed information, and see locations on a map.
     - Tap on a customer to view their full profile, including financial data and sales information.
     - Use the map view to see the customer's location and get directions.
   - **Vendors**: Browse vendors, view detailed information, and visualize locations.
     - Tap on a vendor to see their complete profile, including contact details and financial information.
     - Use the map view to locate vendors geographically.
   - **Orders**: Access and view order information from Business Central.
     - See a list of all orders with key information like customer name, date, and total amount.
     - Tap on an order to view more details (feature coming soon).
   - **Settings**: Configure and manage your Business Central connection settings.
3. Use the search functionality to quickly find specific customers, vendors, or orders.
4. Pull down to refresh the data on any list view.
5. Tap on any address to open it in the Maps app for directions.

Note: Some features may require an active internet connection to sync with Business Central.

## API Pages

The BCConnector app requires certain API Pages to be created via an app extension. These API Pages can be found in the following repository:

[https://github.com/yannstlo/BCAPIForIosApp](https://github.com/yannstlo/BCAPIForIosApp) **(Coming Soon)**

Please follow the instructions in the BCAPIForIosApp repository to set up the necessary API Pages for your BCConnector app. These API Pages are essential for the app to function properly and connect to the required data sources.

## Contributing

We welcome contributions to the BCConnector project! If you'd like to contribute, please follow these steps:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please ensure your code adheres to the project's coding standards and includes appropriate tests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please file an issue on the GitHub repository.

## Acknowledgements

- SwiftUI for providing a powerful framework for building user interfaces
- Microsoft for their Dynamics 365 Business Central platform and authentication services
- [aider.chat](https://aider.chat) for assistance in creating this app

## Prerequisites

Before using the BCConnector app, you need to set up the following:

1. **Azure App Registration**: 
   - Register your app in the Azure portal
   - Configure the necessary permissions for Business Central API access
   - Note down the Client ID and Client Secret

2. **Business Central Entra Application**:
   - Set up an Entra Application in your Business Central environment
   - Configure the appropriate user permissions and roles

Ensure both the Azure App Registration and BC Entra Application are properly configured for the BCConnector app to function correctly.
