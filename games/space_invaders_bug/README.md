# Space Invaders

A short demo game where you control a spaceship left and right with your mouse, and use the spacebar key to shoot lasers at bugs. When you kill enough bugs, you face the Bee Boss, where it will spawn mini-minions to attack you.

There are several Rive assets for the different types of bugs, the spaceship, and lasers.

This example demonstrates ways to:
- Instance multiple of the same Rive Artboard from one file
- Batch advancing state machines and their associated artboards (performance gain)
- One method to do plain hit detection on the bounds of the Artboard (or a group)
- Procedurally created Rive paths to create dynamic shapes
- Properly decomposing/destroying unnecessary Rive instanced Artboards, State Machines, etc. when unneeded

## How to Run

Note that you'll need access to Rive GameKit to run this example. Once you do:

1. Clone the `rive-gamekit-examples` repo down to your machine
2. `cd games/space_invaders_bug`
3. Run `flutter create .` to create all the platform-specific folder builds and projects
3. To run the application as a macOS app, run `flutter run -d macos`

Note the platform support for Rive GameKit in the [Rive docs](https://help.rive.app/rive-gamekit/overview) before running on other platforms.

## Rive Assets Usesd

- SpaceShip: https://rive.app/community/4894-9900-ship-gamekit-demo/
- Bug 1: https://rive.app/community/4895-9902-bug-enemy/
