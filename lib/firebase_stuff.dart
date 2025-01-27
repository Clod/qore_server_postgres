// Import the openid_client package
import 'package:openid_client/openid_client.dart';
// Import the qore_server_postgres_funcs package
import 'package:qore_server_postgres/qore_server_postgres_funcs.dart';

// Function to validate a user's Firebase token
Future<bool> validateUserFirebaseToken(String token) async {

  // Initialize tokenOK to true
  bool tokenOK = true;
  // Print a list of known issuers
  logger.d(Issuer.knownIssuers);

  // Discover the metadata of the Google OP
  var issuer = await Issuer.discover(Issuer.firebase("cardio-gut"));
  // Create a client
  var client = Client(issuer, "cardio-gut");

  // Create a credential
  var c = client.createCredential(idToken: token);

  // Log the client ID
  logger.t(c.client.clientId);
  // Log the user's name from the ID token
  logger.t(c.idToken.claims.name);

  // Validate the token
  var violations = c.validateToken(validateClaims: true, validateExpiry: true);

  // Iterate through any validation violations
   await for (final e in violations) {
     // Log each violation
     logger.d(e.toString());
     // Set tokenOK to false if there are any violations
     tokenOK = false;
   }

   // Return whether the token is valid
   return tokenOK;
}
