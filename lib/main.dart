import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import './Screen/customTextField.dart';
import 'dart:math' show cos, asin, sqrt;

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
  Set<Marker> markers = {};
  PolylinePoints polylinePoints;
  List<LatLng> polylineCoordinates = [];
  Set<Polyline> polyline = {};
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  //helper function
  Future<void> _createPolyLinePoints(
      Position start, Position destination) async {
    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        'AIzaSyAb3gV4RogsdL9SkFYMHXdzAsNFo7C_Hpc',
        PointLatLng(start.latitude, start.longitude),
        PointLatLng(destination.latitude, destination.longitude),
        travelMode: TravelMode.driving);
    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
      polyline.add(Polyline(
          width: 4,
          color: Theme.of(context).accentColor,
          polylineId: PolylineId('$_currentPosition'),
          points: polylineCoordinates,
          endCap: Cap.roundCap,
          startCap: Cap.buttCap,
          visible: true));
    }
  }

  Future<void> _getAddress() async {
    Placemark place;
    try {
      await geoLocator
          .placemarkFromCoordinates(
              _currentPosition.latitude, _currentPosition.longitude)
          .then((p) {
        place = p[0]; //most preferred one);
      });
      setState(() {
        _currentAddress =
            "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e.toString());
    }
  }

  // class instances

  Future<void> getCurrentLocation() async {
    await geoLocator
        .getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        )
        .then((Position position) => setState(() {
              _currentPosition = position;
            }));
    await _getAddress();
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

  Future<bool> _calculateDistance() async {
    try {
      List<Placemark> startPlaceMark =
          await geoLocator.placemarkFromAddress(_startAddress);
      List<Placemark> destinationPlaceMark =
          await geoLocator.placemarkFromAddress(_destinationAddress);
      if (startPlaceMark != null && destinationPlaceMark != null) {
        Position startCoordinates = _startAddress == _currentAddress
            ? Position(
                latitude: _currentPosition.latitude,
                longitude: _currentPosition.longitude)
            : startPlaceMark[0].position;
        Position destinationCoordinates = destinationPlaceMark[0].position;
        Marker startMarker = Marker(
            markerId: MarkerId('$startCoordinates'),
            position: LatLng(
              startCoordinates.latitude,
              startCoordinates.longitude,
            ),
            infoWindow: InfoWindow(title: 'Start', snippet: _startAddress),
            icon: BitmapDescriptor.defaultMarker);
        Marker destinationMarker = Marker(
            markerId: MarkerId('$destinationCoordinates'),
            position: LatLng(destinationCoordinates.latitude,
                destinationCoordinates.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            infoWindow:
                InfoWindow(title: 'DEST', snippet: _destinationAddress));
        // adding marker to set .
        markers.add(startMarker);
        markers.add(destinationMarker);
        Position _northeastCoordinates;
        Position _southwestCoordinates;
// Calculating to check t
// southwest coordinate <= northeast coordinate
        if (startCoordinates.latitude <= destinationCoordinates.latitude) {
          _southwestCoordinates = startCoordinates;
          _northeastCoordinates = destinationCoordinates;
        } else {
          _southwestCoordinates = destinationCoordinates;
          _northeastCoordinates = startCoordinates;
        }

// Accommodate the two locations within the
// camera view of the map
        mapController
            .animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              northeast: LatLng(
                _northeastCoordinates.latitude,
                _northeastCoordinates.longitude,
              ),
              southwest: LatLng(
                _southwestCoordinates.latitude,
                _southwestCoordinates.longitude,
              ),
            ),
            100.0, // padding
          ),
        )
            .then((value) {
          mapController.animateCamera(CameraUpdate.zoomIn());
        });
        await _createPolyLinePoints(startCoordinates, destinationCoordinates);
        double distance = 0.0;
        double _coordinateDistance(lat1, lon1, lat2, lon2) {
          var p = 0.017453292519943295;
          var c = cos;
          var a = 0.5 -
              c((lat2 - lat1) * p) / 2 +
              c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
          return 12742 * asin(sqrt(a));
        }

        for (int i = 0; i < polylineCoordinates.length - 1; i++) {
          distance += _coordinateDistance(
            polylineCoordinates[i].latitude,
            polylineCoordinates[i].longitude,
            polylineCoordinates[i + 1].latitude,
            polylineCoordinates[i + 1].longitude,
          );
        }

// Storing the calculated total distance of the route
        setState(() {
          _placeDistance = distance.toStringAsFixed(2);
          print('DISTANCE: $_placeDistance km');
        });
      }
    } catch (e) {
      print(e.toString());
    }
    return true;
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
      key: _scaffoldKey,
      body: Container(
        height: height,
        width: width,
        child: Stack(
          children: <Widget>[
            GoogleMap(
              polylines: markers != null ? polyline : null,
              markers: markers != null ? Set<Marker>.from(markers) : null,
//              markers: markers,
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
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.all(
                        Radius.circular(20.0),
                      ),
                    ),
                    width: width * 0.9,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Places',
                            style: TextStyle(fontSize: 20.0),
                          ),
                          SizedBox(height: 10),
                          CustomTextField.textField(
                              label: 'Start',
                              hint: 'Choose starting point',
                              initialValue: _currentAddress,
                              prefixIcon: Icon(Icons.looks_one),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.my_location),
                                onPressed: () {
                                  startAddressController.text = _currentAddress;
                                  _startAddress = _currentAddress;
                                },
                              ),
                              controller: startAddressController,
                              width: width,
                              locationCallback: (String value) {
                                setState(() {
                                  _startAddress = value;
                                });
                              }),
                          SizedBox(height: 10),
                          CustomTextField.textField(
                              label: 'Destination',
                              hint: 'Choose destination',
                              initialValue: '',
                              prefixIcon: Icon(Icons.looks_two),
                              controller: destinationAddressController,
                              width: width,
                              locationCallback: (String value) {
                                setState(() {
                                  _destinationAddress = value;
                                });
                              }),
                          SizedBox(height: 10),
                          Visibility(
                            visible: _placeDistance == null ? false : true,
                            child: Text(
                              'DISTANCE: $_placeDistance km',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          RaisedButton(
                            onPressed: (_startAddress != '' &&
                                    _destinationAddress != '')
                                ? () async {
                                    setState(() {
//                                      polyline.clear();
//                                      markers.clear();
//                                      polylineCoordinates.clear();
//                                      _placeDistance = null;
                                      if (markers.isNotEmpty) markers.clear();
                                      if (polyline.isNotEmpty) polyline.clear();
                                      if (polylineCoordinates.isNotEmpty)
                                        polylineCoordinates.clear();
                                      _placeDistance = null;
                                    });
                                    await _calculateDistance().then((value) {
                                      if (value) {
                                        _scaffoldKey.currentState
                                            .showSnackBar(SnackBar(
                                          content: Text('Good to go'),
                                          action: SnackBarAction(
                                            onPressed: () {},
                                            label: 'UNDO',
                                          ),
                                        ));
                                      } else {
                                        _scaffoldKey.currentState
                                            .showSnackBar(SnackBar(
                                          content: Text('an Error occurred!'),
                                        ));
                                      }
                                      setState(() {});
                                    });
                                  }
                                : null,
                            color: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Show Route'.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
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
