// ignore_for_file: use_build_context_synchronously


import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/models/booking_model.dart';
import 'package:frontend/models/mess_menu_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:frontend/utils/bus_schedule.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

import 'dio_non_web_config.dart' if (dart.library.html) 'dio_web_config.dart';

class ApiServices {
  static final ApiServices _instance = ApiServices._internal();
  factory ApiServices() => _instance;

  ApiServices._internal();

  PersistCookieJar? cookieJar;
  String backendUrl = dotenv.env["BACKEND_URL"] ?? "";

  Dio dio = Dio();

  Future<void> configureDio() async {
    final dioConfig = DioConfig();
    final client = dioConfig.getClient();
    client.options.baseUrl = backendUrl;
    dio = client;

    if (!kIsWeb) {
      // Initialize cookie jar for non-web platforms
      var appDocDir = await getApplicationDocumentsDirectory();
      var cookiePath = "${appDocDir.path}/.cookies/";
      cookieJar = PersistCookieJar(storage: FileStorage(cookiePath));
      dio.interceptors.add(CookieManager(cookieJar!));
    }

    debugPrint("Dio configured with base URL: ${dio.options.baseUrl}");
  }

  //======================================================================
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ["email"]);

  Future<void> googleLogout() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }

  void showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Session Expired Please Login again!'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    await googleLogout();
    showError(context);
  }

  Future<void> serverLogout() async {
    await dio.get('/auth/logout');
  }

  Future<Map<String, dynamic>> login(String idToken) async {
    try {
      debugPrint("Making request to: ${dio.options.baseUrl}/auth/login");
      final response =
          await dio.post('/auth/login', data: {'id_token': idToken});
      final data = response.data;
      final userModel =
          UserModel(id: data['id'], email: data['email'], name: '');
      return {'user': userModel, 'status': response.statusCode};
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        return {'error': e.response?.data['detail']['error'], 'status': 401};
      }
      debugPrint("Login failed: $e");
      return {'error': 'Login failed', 'status': e.response?.statusCode};
    }
  }

  Future<MessMenuModel?> getMessMenu(BuildContext context) async {
    try {
      debugPrint("Making request to: ${dio.options.baseUrl}/mess_menu");
      final response = await dio.get('/mess_menu/');

      if (response.statusCode == 401) {
        await logout(context);
        return null;
      }

      final data = response.data;
      return MessMenuModel.fromJson(data);
    } catch (e) {
      debugPrint("Failed to fetch mess menu: $e");
      return null;
    }
  }

  Future<BusSchedule?> getBusSchedule(BuildContext context) async {
    try {
      debugPrint("Making request to: ${dio.options.baseUrl}/bus_schedule");
      final response = await dio.get('/bus_schedule/');

      if (response.statusCode == 401) {
        await logout(context);
        return null;
      }

      final data = response.data;
      return BusSchedule.fromJson(data);
    } catch (e) {
      debugPrint("Failed to fetch bus schedule: $e");
      return null;
    }
  }

  Future<UserModel?> getUserDetails(BuildContext context) async {
    try {
      debugPrint("Making request to: ${dio.options.baseUrl}/user");
      final response = await dio.get('/user/');

      if (response.statusCode == 401) {
        await logout(context);
        return null;
      }

      final data = response.data;
      return UserModel(
          email: data['email'],
          name: data['name'],
          cr: data['cr'],
          phone: data['phone_number'],
          id: data['id']);
    } catch (e) {
      debugPrint("Failed to fetch bus schedule: $e");
      return null;
    }
  }

  // ====================CAB SHARING STARTS===================================

  Future<List<BookingModel>> getBookings(BuildContext context,
      {String? fromLoc,
      String? toLoc,
      String? startTime,
      String? endTime}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (fromLoc != null) queryParams['from_loc'] = fromLoc;
      if (toLoc != null) queryParams['to_loc'] = toLoc;
      if (startTime != null) queryParams['start_time'] = startTime;
      if (endTime != null) queryParams['end_time'] = endTime;

      debugPrint(
          "Making request to: ${dio.options.baseUrl}/cabshare/bookings with params: $queryParams");
      final response = await dio.get('/cabshare/bookings',
          queryParameters: queryParams.isEmpty ? null : queryParams);

      if (response.statusCode == 401) {
        await logout(context);
        return [];
      }

      final data = response.data as List;
      return data.map((booking) => BookingModel.fromJson(booking)).toList();
    } catch (e) {
      debugPrint("Failed to fetch bookings: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createBooking(BookingModel booking) async {
    try {
      final response = await dio.post(
        '/cabshare/bookings',
        data: booking.toJson(),
      );
      return {
        'booking': response.data,
        'status': response.statusCode,
        'error': null
      };
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'error': e.response?.data['detail'],
          'status': e.response?.statusCode
        };
      }
      debugPrint("Create booking failed: $e");
      return {
        'error': 'Create booking failed',
        'status': e.response?.statusCode
      };
    }
  }

  Future<Map<String, dynamic>> updateBooking(
      int bookingId, BookingModel booking) async {
    try {
      final response = await dio.patch(
        '/cabshare/bookings/$bookingId',
        data: booking.toJson(),
      );
      return {'booking': response.data, 'status': response.statusCode};
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'error': e.response?.data['detail'],
          'status': e.response?.statusCode
        };
      }
      debugPrint("Update booking failed: $e");
      return {
        'error': 'Update booking failed',
        'status': e.response?.statusCode
      };
    }
  }

  Future<List<BookingModel>> getUserBookings(BuildContext context) async {
    try {
      debugPrint(
          "Making request to: ${dio.options.baseUrl}/cabshare/me/bookings");
      final response = await dio.get('/cabshare/me/bookings');

      if (response.statusCode == 401) {
        await logout(context);
        return [];
      }

      final data = response.data["future_bookings"] as List;
      return data.map((booking) => BookingModel.fromJson(booking)).toList();
    } catch (e) {
      debugPrint("Failed to fetch user bookings: $e");
      return [];
    }
  }

  Future<List<BookingModel>> getUserRequests(BuildContext context) async {
    try {
      debugPrint(
          "Making request to: ${dio.options.baseUrl}/cabshare/me/requests");
      final response = await dio.get('/cabshare/me/requests');

      if (response.statusCode == 401) {
        await logout(context);
        return [];
      }

      final data = response.data as List;
      return data.map((booking) => BookingModel.fromJson(booking)).toList();
    } catch (e) {
      debugPrint("Failed to fetch user requests: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> requestToJoinBooking(
      int bookingId, String comments) async {
    try {
      final response = await dio.post(
        '/cabshare/bookings/$bookingId/request',
        data: {'comments': comments},
      );
      return {'status': response.statusCode};
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'error': e.response?.data['detail'],
          'status': e.response?.statusCode
        };
      }
      debugPrint("Request to join booking failed: $e");
      return {
        'error': 'Request to join booking failed',
        'status': e.response?.statusCode
      };
    }
  }

  Future<Map<String, dynamic>> deleteRequest(int bookingId) async {
    try {
      final response =
          await dio.delete('/cabshare/bookings/$bookingId/request');
      return {'status': response.statusCode};
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'error': e.response?.data['detail'],
          'status': e.response?.statusCode
        };
      }
      debugPrint("Delete request failed: $e");
      return {
        'error': 'Delete request failed',
        'status': e.response?.statusCode
      };
    }
  }

  Future<Map<String, dynamic>> acceptRequest(
      int bookingId, String requesterEmail) async {
    try {
      final response = await dio.post(
        '/cabshare/bookings/$bookingId/accept',
        data: {'requester_email': requesterEmail},
      );
      return {'status': response.statusCode};
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'error': e.response?.data['detail'],
          'status': e.response?.statusCode
        };
      }
      debugPrint("Accept request failed: $e");
      return {
        'error': 'Accept request failed',
        'status': e.response?.statusCode
      };
    }
  }

  Future<Map<String, dynamic>> rejectRequest(
      int bookingId, String requesterEmail) async {
    try {
      final response = await dio.post(
        '/cabshare/bookings/$bookingId/reject',
        data: {'requester_email': requesterEmail},
      );
      return {'status': response.statusCode};
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'error': e.response?.data['detail'],
          'status': e.response?.statusCode
        };
      }
      debugPrint("Reject request failed: $e");
      return {
        'error': 'Reject request failed',
        'status': e.response?.statusCode
      };
    }
  }

  Future<Map<String, dynamic>> deleteBooking(int bookingId) async {
    try {
      final response = await dio.delete('/cabshare/bookings/$bookingId');
      return {'status': response.statusCode};
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'error': e.response?.data['detail'],
          'status': e.response?.statusCode
        };
      }
      debugPrint("Delete booking failed: $e");
      return {
        'error': 'Delete booking failed',
        'status': e.response?.statusCode
      };
    }
  }

  Future<Map<String, dynamic>> exitBooking(int bookingId) async {
    try {
      final response = await dio.delete('/cabshare/bookings/$bookingId/self');
      return {'status': response.statusCode};
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'error': e.response?.data['detail'],
          'status': e.response?.statusCode
        };
      }
      debugPrint("Exit booking failed: $e");
      return {'error': 'Exit booking failed', 'status': e.response?.statusCode};
    }
  }

  // ====================CAB SHARING ENDS===================================
}
