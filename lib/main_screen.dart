import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  final xController = TextEditingController();
  final yController = TextEditingController();
  final zController = TextEditingController();

  int xCoordinate = 0;
  int yCoordinate = 0;

  String url = "";

  @override
  void dispose() {
    xController.dispose();
    yController.dispose();
    zController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tile Calculator'),
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 16.0, horizontal: 65.0),
          child: Column(
            children: [
              TextFormField(
                controller: xController,
                decoration: const InputDecoration(
                  labelText: 'Широта',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10.0),
              TextFormField(
                controller: yController,
                decoration: const InputDecoration(
                  labelText: 'Долгота',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10.0),
              TextFormField(
                controller: zController,
                decoration: const InputDecoration(
                  labelText: 'Зум',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15.0),
              GestureDetector(
                onTap: updateTile,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      "Найти плитку",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15.0),
              if (url.isNotEmpty)
                Expanded(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                  ),
                ),
              if (xCoordinate != 0 || yCoordinate != 0) ...[
                const SizedBox(height: 15.0),
                Text('Значение X: $xCoordinate'),
                Text('Значение Y: $yCoordinate'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> updateTile() async {
    if (!_validateForm()) {
      return;
    }

    final z = int.tryParse(zController.text) ?? 0;
    final x = double.tryParse(xController.text) ?? 0.0;
    final y = double.tryParse(yController.text) ?? 0.0;

    final pixelCoords = fromGeoToPixels(x, y, projections[0], z);
    final tileNumber = fromPixelsToTileNumber(pixelCoords[0], pixelCoords[1]);

    setState(() {
      xCoordinate = tileNumber[0];
      yCoordinate = tileNumber[1];
    });

    final tileUrl =
        "https://core-carparks-renderer-lots.maps.yandex.net/maps-rdr-carparks/tiles?l=carparks&x=$xCoordinate&y=$yCoordinate&z=$z&scale=1&lang=ru_RU";

    final response = await http.get(Uri.parse(tileUrl));

    setState(() {
      url = response.statusCode == 200 ? tileUrl : "";
    });

    if (response.statusCode != 200) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text('Плитка не найдена'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('ОК'),
            ),
          ],
        ),
      );
    }
  }

  bool _validateForm() {
    if (xController.text.isEmpty ||
        yController.text.isEmpty ||
        zController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text('Заполните все поля'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('ОК'),
            ),
          ],
        ),
      );
      return false;
    }

    final x = double.tryParse(xController.text);
    final y = double.tryParse(yController.text);

    if (x == null || x < -90 || x > 90) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text(
              'Значение широты должно быть в диапазоне от -90 до 90'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('ОК'),
            ),
          ],
        ),
      );
      return false;
    }

    if (y == null || y < -180 || y > 180) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text(
              'Значение долготы должно быть в диапазоне от -180 до 180'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('ОК'),
            ),
          ],
        ),
      );
      return false;
    }

    return true;
  }
}

// Доступные проекции и соответствующие значения эксцентриситетов
var projections = [
  {
    'name': 'wgs84Mercator',
    'eccentricity': 0.0818191908426,
  },
  {
    'name': 'sphericalMercator',
    'eccentricity': 0,
  }
];

// Функция для перевода географических координат объекта в глобальные пиксельные координаты
List<double> fromGeoToPixels(
    double lat, double long, Map<String, dynamic> projection, int z) {
  final rho = pow(2, z + 8) / 2;
  final beta = lat * pi / 180;
  final phi = (1 - projection['eccentricity'] * sin(beta)) /
      (1 + projection['eccentricity'] * sin(beta));
  final theta =
      tan(pi / 4 + beta / 2) * pow(phi, projection['eccentricity'] / 2);

  final xP = rho * (1 + long / 180);
  final yP = rho * (1 - log(theta) / pi);

  return [xP, yP];
}

// Функция для расчета номера тайла на основе глобальных пиксельных координат
List<int> fromPixelsToTileNumber(double x, double y) {
  return [
    (x / 256).floor(),
    (y / 256).floor(),
  ];
}
