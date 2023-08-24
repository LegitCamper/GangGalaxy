use bevy::prelude::*;

const BACKGROUND_COLOR: Color = Color::rgb(0.9, 0.9, 0.9);

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        // .insert_resource(ClearColor(BACKGROUND_COLOR))
        // .add_startup_system(startup)
        .run();
}

fn startup(mut commands: Commands) {
    commands.spawn(Character);
}

#[derive(Component)]
struct Character;
