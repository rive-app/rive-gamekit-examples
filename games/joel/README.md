# Joel

See the [rive-gamekit-examples](../../README.md) main README for how to get access to the Rive GameKit.

## About

Joel is a Flutter game using the Rive GameKit where you use a joystick to navigate and shoot a hoard of zombies approaching you. It is a true use of GameKit that takes advantage of the new Rive Renderer capabilities to draw tons of vector graphics efficiently.

## How to Run

To play Joel, you can either download the game directly, or run it locally on your machine.

### Download the Game

To simply try out Joel on your macOS device, download the zip for the game [here](https://cdn.rive.app/joel/Joel_1_0_2.zip).

### Locally

Note that you'll need access to Rive GameKit to run this example. Once you do:

1. Clone the `rive-gamekit-examples` repo down to your machine
2. `cd games/joel`
3. Run `flutter create .` to create all the platform-specific folder builds and projects
4. To run the application as a macOS app, run `flutter run -d macos`. 
- By default, we render a **ton** of zombies on the screen to showcase the Rive Renderer capabilities to draw vector graphics efficiently, but if you want to run a simpler mode to better see the details of zombies individually and hits, run the following command: `flutter run --dart-define=NIGHTMARE=false -d macos`

### Platform Considerations
Before running locally, please take note of the [supported platforms and versions](https://help.rive.app/rive-gamekit/overview#supported-platforms-rive-gamekit) section in the Rive GameKit docs.
