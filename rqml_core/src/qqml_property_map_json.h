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

#ifndef RQML_QQML_PROPERTY_MAP_JSON_H
#define RQML_QQML_PROPERTY_MAP_JSON_H

#include <QJSValue>
#include <QQmlPropertyMap>
#include <nlohmann/json.hpp>
#include <qdebug.h>
#include <qml6_ros2_plugin/array.hpp>
#include <qml6_ros2_plugin/time.hpp>

using json = nlohmann::json;

void to_json( json &j, const QVariantMap &map );
void from_json( const json &j, QVariantMap &variant );
void to_json( json &j, const QVariantList &list );
void from_json( const json &j, QVariantList &variant );

void to_json( json &j, const QVariant &variant )
{
  switch ( variant.typeId() ) {
  case QMetaType::Bool:
    j = variant.toBool();
    break;
  case QMetaType::Int:
    j = variant.toInt();
    break;
  case QMetaType::UInt:
    j = variant.toUInt();
    break;
  case QMetaType::Long:
    j = variant.value<long>();
    break;
  case QMetaType::LongLong:
    j = variant.toLongLong();
    break;
  case QMetaType::ULongLong:
    j = variant.toULongLong();
    break;
  case QMetaType::Double:
    j = variant.toDouble();
    break;
  case QMetaType::Char:
    j = variant.toChar().toLatin1();
    break;
  case QMetaType::QVariantMap:
    j = variant.toMap();
    break;
  case QMetaType::QVariantList:
    j = variant.toList();
    break;
  case QMetaType::QString:
    j = variant.toString().toStdString();
    break;
  case QMetaType::QStringList:
    for ( const auto &item : variant.toStringList() ) { j.push_back( item.toStdString() ); }
    break;
  case QMetaType::Nullptr:
    j = json();
    break;
  default:
    if ( variant.isNull() ) {
      j = json();
      break;
    }
    if ( variant.canConvert<QJSValue>() ) {
      auto jsValue = variant.value<QJSValue>();
      j = jsValue.toVariant();
      break;
    }
    if ( variant.typeId() == qMetaTypeId<qml6_ros2_plugin::Array>() ) {
      auto array = variant.value<qml6_ros2_plugin::Array>();
      j = array.toVariantList();
      break;
    }
    if ( variant.typeId() == qMetaTypeId<qml6_ros2_plugin::Time>() ) {
      auto time = variant.value<qml6_ros2_plugin::Time>();
      builtin_interfaces::msg::Time t = time.getTime();
      j["sec"] = t.sec;
      j["nanosec"] = t.nanosec;
      break;
    }
    if ( variant.typeId() == qMetaTypeId<qml6_ros2_plugin::Duration>() ) {
      auto duration = variant.value<qml6_ros2_plugin::Duration>();
      builtin_interfaces::msg::Duration d = duration.getDuration();
      j["sec"] = d.sec;
      j["nanosec"] = d.nanosec;
      break;
    }
    qWarning() << "Unsupported QVariant type:" << variant.typeName() << " (" << variant.typeId()
               << ")";
    break;
  }
}

void from_json( const json &j, QVariant &variant )
{
  switch ( j.type() ) {
  case nlohmann::json::value_t ::null:
  case json::value_t ::discarded:
    variant = QVariant();
    break;
  case json::value_t::string:
    variant = QString::fromStdString( j.get<std::string>() );
    break;
  case json::value_t::boolean:
    variant = j.get<bool>();
    break;
  case json::value_t::number_integer:
    variant = j.get<int>();
    break;
  case json::value_t::number_unsigned:
    variant = j.get<unsigned int>();
    break;
  case json::value_t::number_float:
    variant = j.get<double>();
    break;
  case json::value_t::array: {
    QVariantList list;
    for ( const auto &item : j ) {
      QVariant itemVariant;
      from_json( item, itemVariant );
      list.push_back( itemVariant );
    }
    variant = list;
  } break;
  case json::value_t::object: {
    QVariantMap map;
    for ( const auto &item : j.items() ) {
      auto key = QString::fromStdString( item.key() );
      QVariant value;
      from_json( item.value(), value );
      map.insert( key, value );
    }
    variant = map;
  } break;
  default:
    qDebug() << "Unsupported JSON type:" << j.type_name();
    break;
  }
}

void to_json( json &j, const QVariantMap &map )
{
  j = json::object();
  for ( const auto &key : map.keys() ) {
    const std::string skey = key.toStdString();
    const QVariant value = map.value( key );
    j[skey] = value;
  }
}

void from_json( const json &j, QVariantMap &map )
{

  for ( const auto &[key, value] : j.items() ) {
    map.insert( QString::fromStdString( key ), value.get<QVariant>() );
  }
}

void to_json( json &j, const QVariantList &list )
{
  j = json::array();
  for ( const auto &item : list ) { j.push_back( item ); }
}

void from_json( const json &j, QVariantList &variant )
{
  for ( const auto &item : j ) {
    QVariant itemVariant;
    itemVariant = item.get<QVariant>();
    variant.push_back( itemVariant );
  }
}

void to_json( json &j, const QQmlPropertyMap &map )
{
  j = json::object();
  // Copy the properties from rhs to this node
  for ( const auto &key : map.keys() ) {
    const std::string skey = key.toStdString();
    const QVariant value = map.value( key );
    j[skey] = value;
  }
}

void from_json( const json &j, QQmlPropertyMap &map )
{

  for ( const auto &[key, value] : j.items() ) {
    map.insert( QString::fromStdString( key ), value.get<QVariant>() );
  }
}

#endif // RQML_QQML_PROPERTY_MAP_JSON_H
