# Plugin Development for RQml

RQml uses a plugin system based on QML files and the `ament_index` resource mechanism. This allows you to easily extend the application with custom widgets and tools.

## How it works

1. **QML File**: Each plugin is essentially a QML file that defines the UI and logic of the plugin.
2. **Plugin Declaration**: Plugins are declared in a YAML file (usually named `rqml_plugins.yaml.in`). This file provides metadata about the plugin, such as its ID, name, group, and the path to the QML file.
3. **Registration**: The YAML file is registered as an `rqml_plugin` resource using CMake. This allows the RQml core to discover and load the plugins at runtime.

## Creating a New Plugin

To create a new plugin, follow these steps:

### 1. Create a Package

Create a new ROS 2 package (or use an existing one as template, e.g., the `rqml_plugin_example`).  
Your package should depend on `rqml_core`.

**package.xml**:

```xml
<?xml version='1.0' encoding='UTF-8'?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>my_rqml_plugins</name>
  <version>0.0.0</version>
  <description>My custom RQml plugins</description>
  <maintainer email="user@example.com">User Name</maintainer>
  <license>TODO</license>

  <buildtool_depend>ament_cmake</buildtool_depend>
  <depend>rqml_core</depend>
  <exec_depend>qml6_ros2_plugin</exec_depend>

  <export>
    <!-- This is important for rqml to find your plugin -->
    <build_type>ament_cmake</build_type>
  </export>
</package>
```

### 2. Create the QML Plugin

Create a QML file for your plugin (e.g., `qml/MyPlugin.qml`).

**qml/MyPlugin.qml**:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ros2

Rectangle {
    id: root
    // Set the minimum size for this plugin's dock widget
    property var kddockwidgets_min_size: Qt.size(300, 300)
    color: palette.base

    // ... Your plugin code ...
}
```

### 3. Declare the Plugin

Create a YAML file (e.g., `rqml_plugins.yaml.in`) to declare your plugin.

**rqml_plugins.yaml.in**:

```yaml
plugins:
  - id: my_rqml_plugins.my_plugin
    name: "My Plugin"
    group: "My Group"
    path: "share/@PROJECT_NAME@/qml/MyPlugin.qml"
    single_instance: false
```

* **id**: A unique identifier for your plugin.
* **name**: The display name of the plugin.
* **group**: The category under which the plugin will appear in the menu.
>[!NOTE]
> Please try to use an existing group name where it makes sense.
* **path**: The installation path to the QML file. `@PROJECT_NAME@` will be replaced by CMake.
* **single_instance**: If `true`, only one instance of this plugin can be opened at a time.
    This should rarely be set to true as even plugins that are once per robot may be used in
    multi-robot contexts.

### 4. Configure CMake

Update your `CMakeLists.txt` to install the QML files and register the plugin resource.

**CMakeLists.txt**:

```cmake
cmake_minimum_required(VERSION 3.15)
project(my_rqml_plugins)

find_package(ament_cmake REQUIRED)

# Install QML files
install(DIRECTORY qml DESTINATION share/${PROJECT_NAME})

# Register the plugin resource
ament_index_register_resource(rqml_plugin CONTENT_FILE rqml_plugins.yaml.in)

ament_package()
```

### 5. Build and Run

Build your workspace and source the setup file. RQml should now automatically detect your plugin.

```bash
colcon build --packages-select my_rqml_plugins
source install/setup.bash
rqml
```

You should see "My Plugin" under the "My Group" menu in RQml.  
If not, first try to open a fresh terminal and source your workspace before opening an issue.

## Advanced

### Clipboard

To copy text to the clipboard, you can use `RQml.copyTextToClipboard(text)`.
