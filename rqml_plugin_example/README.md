# rqml_plugin_example

This example package can be used as a starting point for your own plugin package.
In contrast to the other packages in this repository, it is licensed under MIT-0, which
essentially means that you can copy this package and don't have to give any attribution.
For more information, check out [LICENSE](LICENSE).

## Setup Instructions

1. Copy this package and delete the `README.md` and the `LICENSE` file.
2. Rename the directory and update the name of the package in both the `package.xml` and the `CMakeLists.txt`.
3. Update maintainer information, license and description in the `package.xml`.
4. Rename the `ExamplePlugin.qml` in the `qml` directory to a name that fits.
5. Update the name and metadata for your plugin in the `rqml_plugins.yaml.in` file.
6. Implement your plugin the QML file.
7. Build the project and resource your `install/setup.bash`.
8. Run `rqml` and your plugin should be available in the `Plugins` menu.
