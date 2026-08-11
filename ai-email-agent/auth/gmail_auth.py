import os


class AuthenticationError(RuntimeError):
    pass

SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send",
    "https://www.googleapis.com/auth/gmail.modify",
]


def get_gmail_service():
    """
    Retourne un service Gmail authentifie via OAuth 2.0.
    Lance le navigateur pour la premiere authentification,
    puis reutilise le token.json pour les fois suivantes.
    """
    try:
        from google.oauth2.credentials import Credentials
        from google.auth.transport.requests import Request
        from google_auth_oauthlib.flow import InstalledAppFlow
        from googleapiclient.discovery import build
    except ImportError as exc:
        raise AuthenticationError(
            "Les dependances Google Gmail ne sont pas installees. Installez requirements.txt avant d'utiliser Gmail."
        ) from exc

    creds = None

    # Si un token existe deja, le charger
    if os.path.exists("token.json"):
        creds = Credentials.from_authorized_user_file("token.json", SCOPES)

    # Si pas de token valide, en creer un
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            # Token expire mais rafraichissable
            creds.refresh(Request())
        else:
            # Premiere fois : ouvrir le navigateur
            try:
                flow = InstalledAppFlow.from_client_secrets_file(
                    "credentials.json", SCOPES
                )
                creds = flow.run_local_server(port=0)
            except KeyboardInterrupt as exc:
                raise AuthenticationError(
                    "Authentification Gmail annulee. Relancez le script et terminez la connexion dans le navigateur."
                ) from exc
            except Exception as exc:
                raise AuthenticationError(
                    "Impossible de finaliser l'authentification Gmail. Verifiez credentials.json et reessayez."
                ) from exc

        # Sauvegarder pour les prochains appels
        with open("token.json", "w") as token:
            token.write(creds.to_json())

    return build("gmail", "v1", credentials=creds)