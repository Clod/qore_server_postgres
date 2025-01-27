import 'package:qore_server_postgres/firebase_stuff.dart';
import 'package:test/test.dart';

void main() {

  group('Token Validation', () {
    test('Valid Token should return true', () async {
      // Arrange
      final token = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjE5MGFkMTE4YTk0MGFkYzlmMmY1Mzc2YjM1MjkyZmVkZThjMmQwZWUiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vY2FyZGlvLWd1dCIsImF1ZCI6ImNhcmRpby1ndXQiLCJhdXRoX3RpbWUiOjE2OTQ4MDY0NjcsInVzZXJfaWQiOiJIbzB3ZnNwaVBjZTdkWEFpRGljZlBxaGs1NDIyIiwic3ViIjoiSG8wd2ZzcGlQY2U3ZFhBaURpY2ZQcWhrNTQyMiIsImlhdCI6MTY5NDgwNjQ2NywiZXhwIjoxNjk0ODEwMDY3LCJlbWFpbCI6ImouY2xhdWRpby5ncmFzc29AZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImZpcmViYXNlIjp7ImlkZW50aXRpZXMiOnsiZW1haWwiOlsiai5jbGF1ZGlvLmdyYXNzb0BnbWFpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.K46yjFiiA1JOFUYDoJW063BKVuYbT4SkAbeAYH6uWEhZbvDg1JaclzcLTSbveyGLq2ak2SoAyIn4S1d4acrNIfpWgKwNRT7X43blRLR7IA5wL_cOVJgOM68t0Y7H6FhdaQgi2TJRLK9ud0QHGqcV0IdISzBMbGnTE86XIeeYhrmRVmEKt3mx3-fMK00fikN2jsorCdmWh3mHO89FaJYa1evzYM6A2dAjAWK8V7v_twZnucOpW5qWD3c3SgT94Xd_b5YME14vGC6f1tqqKxpe66cvxEW_qSCn7_vJOfV6-2b3PP5N1jsnoUudRT5x_FlZzqIQD8vesvl_X-tTCeH2TA';

      // Act
      final result = await validateUserFirebaseToken(token);

      // Assert
      expect(result, true);
    });

    test('Invalid Token should return false', () async {
      // Arrange
      final token = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjE5MGFkMTE4YTk0MGFkYzlmMmY1Mzc2YjM1MjkyZmVkZThjMmQwZWUiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vY2FyZGlvLWd1dCIsImF1ZCI6ImNhcmRpby1ndXQiLCJhdXRoX3RpbWUiOjE2OTQ3OTM2MzUsInVzZXJfaWQiOiJIbzB3ZnNwaVBjZTdkWEFpRGljZlBxaGs1NDIyIiwic3ViIjoiSG8wd2ZzcGlQY2U3ZFhBaURpY2ZQcWhrNTQyMiIsImlhdCI6MTY5NDc5MzYzNSwiZXhwIjoxNjk0Nzk3MjM1LCJlbWFpbCI6ImouY2xhdWRpby5ncmFzc29AZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImZpcmViYXNlIjp7ImlkZW50aXRpZXMiOnsiZW1haWwiOlsiai5jbGF1ZGlvLmdyYXNzb0BnbWFpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.AMZJjokf_gPXdQQAPMbgN7wL-PNhiOsyn6OwO6lRscLLv419iweroKuTLJTdTAOsu2jG5WakZ4DIQjOin-DVISB-4AYckdDQsR93K65HqFGuTaLpza8uZg_ynEX5RtzGCRFAIST5ewYEQV1adqU9aP--AnozblA2NWhXGndHT8cBFLg_zm3_TdBLvOrQG_6i_o3meZB9vT1XXsd4sjqM45Hv83P30D7jJeW52Fp-JUGqkpj4Ct7isRBvksj93RVn_i1IzP0mg5HwutinxY3NTG8sHAmkvLC3sBbPinyZ7egAyqpewknsHzNci1WAoGGMKy8oveCnJACtmjQPCo062w';

      // Act
      final result = await validateUserFirebaseToken(token);

      // Assert
      expect(result, false);
    });
  });
}
