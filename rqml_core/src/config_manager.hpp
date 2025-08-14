/*
 * Copyright (C) 2025  Stefan Fabian
 *
 * This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef RQML_CORE_CONFIG_MANAGER_HPP
#define RQML_CORE_CONFIG_MANAGER_HPP

#include "plugin_manager.hpp"
#include <QSettings>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

namespace KDDockWidgets
{
class LayoutSaver;
}

namespace rqml
{
class FileSystemWatcher;

struct Config {
  std::filesystem::path path;
};

class ConfigManager : public QObject
{
  Q_OBJECT
public:
  ConfigManager( PluginManager::SharedPtr plugin_manager );
  ~ConfigManager();

  void init();

  void addConfigDirectory( const std::filesystem::path &directory );

  void removeConfigDirectory( const std::filesystem::path &directory );

  void save();

  void save( const std::string &path );

  void load( const std::string &path );

  const std::filesystem::path &currentConfig() const;

  Config getConfig( const std::filesystem::path &path ) const;

  const std::vector<std::filesystem::path> &recentConfigs() const;

  const std::vector<Config> &configs() const;

  const std::vector<std::string> &configDirectories() const;

signals:
  void configsChanged();
  void currentConfigChanged();
  void configDirectoriesChanged();

private slots:
  void checkForFileChanges();

private:
  void loadConfigs();

  void saveConfigDirectories();

  void saveRecentConfigs();

  void setCurrentConfig( const std::string &path );

  QSettings settings_;
  std::vector<std::string> config_directories_;
  std::vector<std::filesystem::path> recent_configs_;
  std::vector<Config> configs_;
  std::filesystem::path current_config_;
  PluginManager::SharedPtr plugin_manager_;
  std::unique_ptr<KDDockWidgets::LayoutSaver> layout_saver_;
  std::unique_ptr<FileSystemWatcher> file_system_watcher_;
  QTimer file_check_timer_;
  size_t max_recent_configs_ = 50;
};
} // namespace rqml

#endif // RQML_CORE_CONFIG_MANAGER_HPP
