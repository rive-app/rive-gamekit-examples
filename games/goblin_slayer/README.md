# Goblin Slayer

See the [rive-gamekit-examples](../../README.md) main README for how to get access to the Rive GameKit.

## About

Goblin Slayer is a Flutter game using the Rive GameKit where you control a knight that, surprise, has to slay goblins.

It's a good showcase on how to make use of a map, player movement, and basic camera controls.

It also makes use of the [Flutter Oxygen package](https://pub.dev/packages/oxygen) as an [ECS system](https://en.wikipedia.org/wiki/Entity_component_system) to manage the game state. This is intendend to serve as an example of one way to structure your game code. We do not recommend using one approach over another. You should use what makes sense for you, your team, and your game.

## How to Run

Note that you'll need access to Rive GameKit to run this example. Once you do:

1. Clone the `rive-gamekit-examples` repo down to your machine
2. `cd games/goblin_slayer`
3. Run `flutter create .` to create all the platform-specific folder builds and projects
4. To run the application as a macOS app, run `flutter run -d macos`

Note the platform support for Rive GameKit in the [Rive docs](https://help.rive.app/rive-gamekit/overview) before running on other platforms.
