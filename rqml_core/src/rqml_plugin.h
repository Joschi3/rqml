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

#ifndef RQML_RQML_PLUGIN_H
#define RQML_RQML_PLUGIN_H

#include <QObject>
#include <QQmlPropertyMap>

class RQmlPlugin
{
  Q_GADGET
  Q_PROPERTY( QString id MEMBER id_ )
  Q_PROPERTY( QString name MEMBER name_ )
  Q_PROPERTY( QString path MEMBER path_ )
  Q_PROPERTY( QString group MEMBER group_ )
  Q_PROPERTY( bool singleInstance MEMBER single_instance_ )
public:
  RQmlPlugin() = default;
  RQmlPlugin( const std::string &id, const std::string &name, const std::string &path,
              const std::string &group, bool single_instance = false )
      : id_( QString::fromStdString( id ) ), name_( QString::fromStdString( name ) ),
        path_( QString::fromStdString( path ) ), group_( QString::fromStdString( group ) ),
        single_instance_( single_instance )
  {
  }

  QString id_;
  QString name_;
  QString path_;
  QString group_;
  bool single_instance_ = false;
};
Q_DECLARE_METATYPE( RQmlPlugin )

class RQmlPluginInstance : public QObject
{
  Q_OBJECT
  Q_PROPERTY( QString uniqueName MEMBER unique_name_ )
  Q_PROPERTY( QQmlPropertyMap *context READ getContext CONSTANT )
public:
  RQmlPluginInstance() = default;
  explicit RQmlPluginInstance( const std::string &unique_name )
      : unique_name_( QString::fromStdString( unique_name ) )
  {
  }

  QQmlPropertyMap *getContext() { return &context_; }

  QString unique_name_;
  QQmlPropertyMap context_;
};

#endif // RQML_RQML_PLUGIN_H
