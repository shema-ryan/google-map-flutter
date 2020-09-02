import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import './Screen/customTextField.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        accentColor: Colors.brown[200],
        primarySwatch: Colors.brown,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Map(),
    );
  }
}

class Map extends StatefulWidget {
  @override
  _MapState createState() => _MapState();
}

class _MapState extends State<Map> {
  //helper variables
  Position _currentPosition;
  Geolocator geoLocator = Geolocator();
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));
  GoogleMapController mapController;
  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();
  String _currentAddress;
  String _startAddress = '';
  String _destinationAddress = '';
  String _placeDistance;

  //helper function
  Future<void> _getAddressAndLocation() async {
    Placemark place;
    try {
      await geoLocator
          .placemarkFromCoordinates(
              _currentPosition.latitude, _currentPosition.longitude)
          .then((p) {
        place = p[0];
      });
      setState(() {
        _currentAddress =
            "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
      List<Placemark> startPlaceMark =
          await geoLocator.placemarkFromAddress(_startAddress);
      List<Placemark> destinationPlaceMark =
          await geoLocator.placemarkFromAddress(_destinationAddress);

// Retrieving coordinates
      Position startCoordinates = startPlaceMark[0].position;
      Position destinationCoordinates = destinationPlaceMark[0].position;
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> getCurrentLocation() async {
    await geoLocator
        .getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        )
        .then((Position position) => setState(() {
              _currentPosition = position;
              print(_currentPosition);
            }));
    mapController
        .animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
            target:
                LatLng(_currentPosition.latitude, _currentPosition.longitude),
            zoom: 12),
      ),
    )
        .catchError((e) {
      print(e.toString());
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    getCurrentLocation();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    final double width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Container(
        height: height,
        width: width,
        child: Stack(
          children: <Widget>[
            GoogleMap(
              initialCameraPosition: _initialLocation,
              myLocationButtonEnabled: false,
              myLocationEnabled: true,
              mapType: MapType.normal,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Material(
                      color: Theme.of(context).accentColor, // button color
                      child: InkWell(
                        splashColor: Colors.brown, // inkwell color
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.add),
                        ),
                        onTap: () {
                          // TODO: Add the operation to be performed
                          mapController.animateCamera(CameraUpdate.zoomIn());
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  ClipOval(
                    child: Material(
                      color: Theme.of(context).accentColor, // button color
                      child: InkWell(
                        splashColor:
                            Theme.of(context).accentColor, // inkwell color
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.remove),
                        ),
                        onTap: () {
                          // TODO: Add the operation to be performed
                          // on button tap
                          mapController.animateCamera(CameraUpdate.zoomOut());
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: ClipOval(
                child: Material(
                  color: Theme.of(context).primaryColor, // button color
                  child: InkWell(
                    splashColor: Theme.of(context).accentColor, // inkwell color
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.my_location),
                    ),
                    onTap: getCurrentLocation,
                    // on button tap
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
