/// The `Authorization` header to load [url] with outside Dio (e.g. an
/// `Image.network` photo), or null when there is no session or [url] isn't
/// on the API's own origin ([apiBaseUrl]'s scheme, host and port). A full
/// URL to another host, such as cloud storage, never gets the token.
Map<String, String>? authHeadersFor(
  String? url, {
  required String? token,
  required String apiBaseUrl,
}) {
  if (url == null || token == null) return null;
  final target = Uri.tryParse(url);
  final api = Uri.tryParse(apiBaseUrl);
  if (target == null || api == null || !target.hasAuthority) return null;
  final sameOrigin =
      target.scheme.toLowerCase() == api.scheme.toLowerCase() &&
      target.host.toLowerCase() == api.host.toLowerCase() &&
      target.port == api.port;
  return sameOrigin ? {'Authorization': 'Bearer $token'} : null;
}
