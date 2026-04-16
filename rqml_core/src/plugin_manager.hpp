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

#ifndef RQML_PLUGIN_LOADER_HPP
#define RQML_PLUGIN_LOADER_HPP

#include "rqml_plugin.h"
#include <QTimer>
#include <memory>
#include <vector>

class QQmlEngine;

namespace KDDockWidgets::Core
{
class DockWidget;
}

namespace KDDockWidgets::QtQuick
{
class DockWidget;
}

namespace rqml
{

class FileSystemWatcher;

class PluginManager : public QObject
{
  Q_OBJECT
public:
  using SharedPtr = std::shared_ptr<PluginManager>;

  explicit PluginManager( QQmlEngine *engine );

  ~PluginManager() final;

  const std::vector<RQmlPlugin> &plugins() const { return plugins_; }

  KDDockWidgets::QtQuick::DockWidget *createPlugin( const QString &plugin_id );

  bool canCreatePlugin( const QString &plugin_id ) const;

  KDDockWidgets::Core::DockWidget *factoryFn( const QString &name );

  static QString extractPluginId( const QString &unique_name )
  {
    return unique_name.left( unique_name.lastIndexOf( '.' ) );
  }

  static std::string extractPluginId( const std::string &unique_name )
  {
    return unique_name.substr( 0, unique_name.find_last_of( '.' ) );
  }

  std::string createUniqueName( const std::string &plugin_id )
  {
    int i = 0;
    while ( instances_.find( plugin_id + "." + std::to_string( i ) ) != instances_.end() ) { ++i; }
    return plugin_id + "." + std::to_string( i );
  }

  void setLiveReloadEnabled( bool value );

  bool liveReloadEnabled() const { return live_reload_enabled_; }

  bool hasInstance( const std::string &unique_name ) const
  {
    return instances_.find( unique_name ) != instances_.end();
  }

  RQmlPluginInstance &getInstance( const std::string &unique_name )
  {
    return *instances_.at( unique_name );
  }

  void clearInstances() { instances_.clear(); }

  void registerInstance( std::unique_ptr<RQmlPluginInstance> instance )
  {
    instances_.try_emplace( instance->unique_name_.toStdString(), std::move( instance ) );
  }

private slots:
  void checkForChanges();

  void onOpenChanged( bool open );

private:
  void loadPluginsFromResource( const std::string &name, const std::string &path );

  std::vector<RQmlPlugin>::const_iterator findPluginById( const QString &plugin_id );

  void reloadWidgets();

  void onFileLoaded( const QString &path );

  class UrlInterceptor;

private:
  std::vector<RQmlPlugin> plugins_;
  std::unordered_map<std::string, std::unique_ptr<RQmlPluginInstance>> instances_;
  QTimer changed_check_timer_;
  QQmlEngine *engine_;
  std::unique_ptr<UrlInterceptor> interceptor_;
  std::unique_ptr<FileSystemWatcher> watcher_;
  bool live_reload_enabled_ = false;
};
} // namespace rqml

#endif // RQML_PLUGIN_LOADER_HPP
