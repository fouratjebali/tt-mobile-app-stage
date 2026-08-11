import os


class AuthenticationError(RuntimeError):
    pass

SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send",
    "https://www.googleapis.com/auth/gmail.modify",
]


CREDENTIALS_FILE = "credentials.json"
TOKEN_FILE = "token.json"


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
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

    # Si pas de token valide, en creer un
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            # Token expire mais rafraichissable
            creds.refresh(Request())
        else:
            if not os.path.exists(CREDENTIALS_FILE):
                raise AuthenticationError(
                    f"Missing {CREDENTIALS_FILE}. Download the OAuth Desktop app JSON from Google Cloud "
                    f"and place it in the ai-email-agent folder as {CREDENTIALS_FILE}."
                )

            # Premiere fois : ouvrir le navigateur
            try:
                flow = InstalledAppFlow.from_client_secrets_file(
                    CREDENTIALS_FILE, SCOPES
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
        with open(TOKEN_FILE, "w") as token:
            token.write(creds.to_json())

    return build("gmail", "v1", credentials=creds)
