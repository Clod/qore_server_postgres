import 'package:openid_client/openid_client.dart';
import 'package:qore_server_postgres/qore_server_postgres_funcs.dart';

Future<bool> validateUserFirebaseToken(String token) async {

  bool tokenOK = true;
  // print a list of known issuers
  print(Issuer.knownIssuers);

  // discover the metadata of the google OP
  var issuer = await Issuer.discover(Issuer.firebase("cardio-gut"));
  // create a client
  var client = Client(issuer, "cardio-gut");

  var c = client.createCredential(idToken: token);

  logger.t(c.client.clientId);
  logger.t(c.idToken.claims.name);

  var violations = c.validateToken(validateClaims: true, validateExpiry: true);

   await for (final e in violations) {
     logger.d(e.toString());
     tokenOK = false;
   }

   return tokenOK;
}