import 'dart:math';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

final backendUri =
    'https://fe1279e1-4f0d-4669-9c46-b50b71bdcdd3.mock.pstmn.io/api/doorbell';

List<String> imgList = [];
List<String> audioList = [];
List<String> metadataList = [];

class _MyAppState extends State<MyApp> {
  late AudioPlayer _player;
  late int selectedDoorbell;
  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    if (!kIsWeb) {
      _player.playerStateStream.listen((state) {
        if (state.playing &&
            state.processingState != ProcessingState.idle &&
            state.processingState != ProcessingState.completed) {
          _player.startVisualizer(
              enableWaveform: true, enableFft: false, captureRate: 25000);
        } else {
          _player.stopVisualizer();
        }
      });
    }
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
  }

  Future<void> getData() async {
    var response = await http.get(Uri.parse(backendUri));
    if (response.statusCode == 200) {
      var data = response.body; //store response as string
      setState(() {
        /*imgList.removeRange(0, imgList.length - 1);
      (jsonDecode(data)['imageUriEndpoints'] as List<dynamic>)
            .cast<String>()
            .forEach((element) {
          imgList.add(element);
        });*/
        imgList.addAll((jsonDecode(data)['imageUriEndpoints'] as List<dynamic>)
            .cast<String>());
        /*imgList = (jsonDecode(data)['imageUriEndpoints'] as List<dynamic>)
          .cast<String>();*/
        print(imgList.length); // just printed length of data
        audioList.addAll(
            (jsonDecode(data)['audioUriEndpoints'] as List<dynamic>)
                .cast<String>());
        print(audioList.length);
        metadataList.addAll(
            (jsonDecode(data)['metadata'] as List<dynamic>).cast<String>());
      });
    } else {
      print(response.statusCode);
    }
  }

  Future<bool> sendData(Map data) async {
    var response = await http.post(Uri.parse(backendUri),
        headers: {"Content-Type": "application/json"}, body: jsonEncode(data));
    if (response.statusCode == 200) {
      print('succesfully posted ${data} to ${backendUri}');
      return true;
    }
    print('error while posting ${data} to ${backendUri}');
    return false;
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    try {
      //await _player.setAudioSource(_playlist);
      await getData();
      /*final List<AudioSource> test = audioList.map(item) => AudioSource.uri(
        Uri.parse(item), 
        tag: AudioMetaData(album: metadata[audioList.indexOf(item)]));*/
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(audioList[0]),
        tag: AudioMetadata(
          album: metadataList[0],
          title: "something ${metadataList[0]}",
          artwork: imgList[0],
        ),
      ));
    } catch (e) {
      // catch load errors: 404, invalid url ...
      print("An error occured $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

/*  List<Widget> imageSliders = imgList
      .map((item) => Container(
            child: Container(
              margin: EdgeInsets.all(5.0),
              child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(5.0)),
                  child: Stack(
                    children: <Widget>[
                      Image.network(item, fit: BoxFit.cover, width: 1000.0),
                      Positioned(
                        bottom: 0.0,
                        left: 0.0,
                        right: 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(200, 0, 0, 0),
                                Color.fromARGB(0, 0, 0, 0)
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                              vertical: 10.0, horizontal: 20.0),
                          child: Text(
                            //'${metadata[imgList.indexOf(item)]}',
                            'when does this init?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )),
            ),
          ))
      .toList();
*/
  Future<void> playNewSound(
      int index, CarouselPageChangedReason changeReason) async {
    selectedDoorbell = index;
    await _player.stop();
    await _player.setAudioSource(AudioSource.uri(
      Uri.parse(audioList[index]),
      tag: AudioMetadata(
        album: metadataList[index],
        title: "A Salute To ${index}",
        artwork: imgList[index],
      ),
    ));
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: StreamBuilder<SequenceState?>(
                  stream: _player.sequenceStateStream,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    if (state?.sequence.isEmpty ?? true) return SizedBox();
                    final metadata = state!.currentSource!.tag as AudioMetadata;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(
                                child: CarouselSlider.builder(
                                    itemCount: imgList.length,
                                    options: CarouselOptions(
                                      autoPlay: false,
                                      aspectRatio: 2.0,
                                      enlargeCenterPage: true,
                                      onPageChanged: playNewSound,
                                    ),
                                    //items: imageSliders,
                                    itemBuilder: (context, index, realIdx) {
                                      return Container(
                                        child: Stack(
                                          children: <Widget>[
                                            Image.network(imgList[index],
                                                fit: BoxFit.cover,
                                                width: 1000.0),
                                            Positioned(
                                              bottom: 0.0,
                                              left: 0.0,
                                              right: 0.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color.fromARGB(
                                                          200, 0, 0, 0),
                                                      Color.fromARGB(0, 0, 0, 0)
                                                    ],
                                                    begin:
                                                        Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                  ),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 10.0,
                                                    horizontal: 20.0),
                                                child: Text(
                                                  '${metadataList[index]}',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20.0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        /*child: Container(
                                          margin: EdgeInsets.all(5.0),
                                          child: ClipRRect(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(5.0)),
                                              child: Stack(
                                                children: <Widget>[
                                                  Image.network(imgList[index],
                                                      fit: BoxFit.cover,
                                                      width: 1000.0),
                                                  Positioned(
                                                    bottom: 0.0,
                                                    left: 0.0,
                                                    right: 0.0,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            Color.fromARGB(
                                                                200, 0, 0, 0),
                                                            Color.fromARGB(
                                                                0, 0, 0, 0)
                                                          ],
                                                          begin: Alignment
                                                              .bottomCenter,
                                                          end: Alignment
                                                              .topCenter,
                                                        ),
                                                      ),
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 10.0,
                                                              horizontal: 20.0),
                                                      child: Text(
                                                        '${metadataList[index]}',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20.0,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )),
                                        ),*/
                                      );
                                      /*Container(
                                          child: Center(
                                        child: Image.network(imgList[index],
                                            fit: BoxFit.cover),
                                      ))*/
                                    })),
                          ),
                        ),
                        Text(metadata.album,
                            style: Theme.of(context).textTheme.headline6),
                        Text(metadata.title),
                      ],
                    );
                  },
                ),
              ),
              if (!kIsWeb)
                Container(
                  height: 50.0,
                  width: double.maxFinite,
                  child: StreamBuilder<VisualizerWaveformCapture>(
                    stream: _player.visualizerWaveformStream,
                    builder: (context, snapshot) {
                      if (snapshot.data == null) return SizedBox();
                      return AudioVisualizerWidget(snapshot.data!);
                    },
                  ),
                ),
              ControlButtons(_player),
              StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (context, snapshot) {
                  final duration = snapshot.data ?? Duration.zero;
                  return StreamBuilder<PositionData>(
                    stream: Rx.combineLatest2<Duration, Duration, PositionData>(
                        _player.positionStream,
                        _player.bufferedPositionStream,
                        (position, bufferedPosition) =>
                            PositionData(position, bufferedPosition)),
                    builder: (context, snapshot) {
                      final positionData = snapshot.data ??
                          PositionData(Duration.zero, Duration.zero);
                      var position = positionData.position;
                      if (position > duration) {
                        position = duration;
                      }
                      var bufferedPosition = positionData.bufferedPosition;
                      if (bufferedPosition > duration) {
                        bufferedPosition = duration;
                      }
                      return SeekBar(
                        duration: duration,
                        position: position,
                        bufferedPosition: bufferedPosition,
                        onChangeEnd: (newPosition) {
                          _player.seek(newPosition);
                        },
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 100.0),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.doorbell),
          onPressed: () async {
            print(
                'Selecting ${metadataList[selectedDoorbell]} (${audioList[selectedDoorbell]})');
            var data = <String, String>{
              'NewDoorbell': selectedDoorbell.toString()
            };
            await sendData(data);
          },
        ),
      ),
    );
  }
}

class AudioVisualizerWidget extends StatelessWidget {
  final VisualizerWaveformCapture capture;

  AudioVisualizerWidget(this.capture);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        painter: AudioVisualizerPainter(capture),
      ),
    );
  }
}

class AudioVisualizerPainter extends CustomPainter {
  final VisualizerWaveformCapture capture;
  final Paint barPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = Colors.blue;

  AudioVisualizerPainter(this.capture);

  @override
  void paint(Canvas canvas, Size size) {
    int getSample(double d) {
      final i = d.toInt();
      if (i >= 0 && i < capture.data.length) {
        return capture.data[i] - 128;
      } else {
        return 0;
      }
    }

    const barCount = 120;
    final barWidth = size.width / barCount;
    final midY = size.height / 2;
    for (var barX = 0.0; barX < size.width; barX += barWidth) {
      final sample = getSample(barX);
      canvas.drawLine(
          Offset(barX.toDouble(), midY),
          Offset(barX.toDouble(), midY - sample * size.height / 2 / 128),
          barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioVisualizerPainter oldDelegate) {
    return true;
  }
}

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  ControlButtons(this.player);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.volume_up),
          onPressed: () {
            _showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, snapshot) => IconButton(
            icon: Icon(Icons.skip_previous),
            onPressed: player.hasPrevious ? player.seekToPrevious : null,
          ),
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero,
                    index: player.effectiveIndices!.first),
              );
            }
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, snapshot) => IconButton(
            icon: Icon(Icons.skip_next),
            onPressed: player.hasNext ? player.seekToNext : null,
          ),
        ),
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              _showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}

class SeekBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final ValueChanged<Duration>? onChanged;
  final ValueChanged<Duration>? onChangeEnd;

  SeekBar({
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;
  late SliderThemeData _sliderThemeData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _sliderThemeData = SliderTheme.of(context).copyWith(
      trackHeight: 2.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SliderTheme(
          data: _sliderThemeData.copyWith(
            thumbShape: HiddenThumbComponentShape(),
            activeTrackColor: Colors.blue.shade100,
            inactiveTrackColor: Colors.grey.shade300,
          ),
          child: ExcludeSemantics(
            child: Slider(
              min: 0.0,
              max: widget.duration.inMilliseconds.toDouble(),
              value: widget.bufferedPosition.inMilliseconds.toDouble(),
              onChanged: (value) {
                setState(() {
                  _dragValue = value;
                });
                if (widget.onChanged != null) {
                  widget.onChanged!(Duration(milliseconds: value.round()));
                }
              },
              onChangeEnd: (value) {
                if (widget.onChangeEnd != null) {
                  widget.onChangeEnd!(Duration(milliseconds: value.round()));
                }
                _dragValue = null;
              },
            ),
          ),
        ),
        SliderTheme(
          data: _sliderThemeData.copyWith(
            inactiveTrackColor: Colors.transparent,
          ),
          child: Slider(
            min: 0.0,
            max: widget.duration.inMilliseconds.toDouble(),
            value: min(_dragValue ?? widget.position.inMilliseconds.toDouble(),
                widget.duration.inMilliseconds.toDouble()),
            onChanged: (value) {
              setState(() {
                _dragValue = value;
              });
              if (widget.onChanged != null) {
                widget.onChanged!(Duration(milliseconds: value.round()));
              }
            },
            onChangeEnd: (value) {
              if (widget.onChangeEnd != null) {
                widget.onChangeEnd!(Duration(milliseconds: value.round()));
              }
              _dragValue = null;
            },
          ),
        ),
        Positioned(
          right: 16.0,
          bottom: 0.0,
          child: Text(
              RegExp(r'((^0*[1-9]\d*:)?\d{2}:\d{2})\.\d+$')
                      .firstMatch("$_remaining")
                      ?.group(1) ??
                  '$_remaining',
              style: Theme.of(context).textTheme.caption),
        ),
      ],
    );
  }

  Duration get _remaining => widget.duration - widget.position;
}

void _showSliderDialog({
  required BuildContext context,
  required String title,
  required int divisions,
  required double min,
  required double max,
  String valueSuffix = '',
  required Stream<double> stream,
  required ValueChanged<double> onChanged,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: StreamBuilder<double>(
        stream: stream,
        builder: (context, snapshot) => Container(
          height: 100.0,
          child: Column(
            children: [
              Text('${snapshot.data?.toStringAsFixed(1)}$valueSuffix',
                  style: TextStyle(
                      fontFamily: 'Fixed',
                      fontWeight: FontWeight.bold,
                      fontSize: 24.0)),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                value: snapshot.data ?? 1.0,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AudioMetadata {
  final String album;
  final String title;
  final String artwork;

  AudioMetadata(
      {required this.album, required this.title, required this.artwork});
}

class HiddenThumbComponentShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.zero;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {}
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;

  PositionData(this.position, this.bufferedPosition);
}
