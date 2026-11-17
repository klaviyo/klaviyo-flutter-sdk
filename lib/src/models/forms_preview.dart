/// Key carrying a forms preview token as a deep link query parameter.
const String formsPreviewTokenKey = 'klaviyo-forms-preview';

final RegExp _formsPreviewTokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

/// True if [token] is a well-formed forms preview token. Does not trim.
bool isValidFormsPreviewToken(String? token) =>
    token != null && _formsPreviewTokenPattern.hasMatch(token);
