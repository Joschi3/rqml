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
#ifndef DEPTH_IMAGE_PROCESSOR_HPP
#define DEPTH_IMAGE_PROCESSOR_HPP

#include <QObject>
#include <QVideoFrame>
#include <QVideoSink>
#include <QtQml/qqmlregistration.h>

class DepthImageProcessor : public QObject
{
  Q_OBJECT
  Q_PROPERTY( QVideoSink *videoSink READ videoSink CONSTANT )
  Q_PROPERTY( QVideoSink *outputVideoSink READ outputVideoSink WRITE setOutputVideoSink NOTIFY
                  outputVideoSinkChanged )
  //! Max depth in meters. Pixels with depth greater than this value will be shown as white. Set to 0 to disable processing.
  Q_PROPERTY( double maxDepth READ maxDepth WRITE setMaxDepth NOTIFY maxDepthChanged )
  QML_ELEMENT

public:
  explicit DepthImageProcessor( QObject *parent = nullptr );

  QVideoSink *videoSink() const;
  QVideoSink *outputVideoSink() const;
  void setOutputVideoSink( QVideoSink *sink );

  double maxDepth() const;
  void setMaxDepth( double depth );

  //! First step to saving an image. Grabs and stores the current processed frame.
  Q_INVOKABLE void grabFrame();

  //! Clear grabbbed frame.
  Q_INVOKABLE void clearGrabbedFrame();

  //! Save the last grabbed frame to the specified path.
  Q_INVOKABLE bool saveGrabbedFrame( const QString &path );

signals:
  void outputVideoSinkChanged();
  void maxDepthChanged();

private slots:
  void processFrame();

private:
  QVideoFrame grabbed_frame_;
  QVideoSink *input_sink_;
  QVideoSink *output_sink_ = nullptr;
  double max_depth_ = 3.0; // Default 3 meters
};

#endif // DEPTH_IMAGE_PROCESSOR_HPP
