#!/usr/bin/env python3
"""Find and optionally delete Firebase Auth users missing from Firestore.

An Auth user is considered active when either:
  * its UID is a document ID in users_2024, or
  * its normalized email appears in the Firestore field "מייל".

The script is a dry run unless --execute is supplied.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Iterable

import firebase_admin
from firebase_admin import auth, credentials, firestore


DEFAULT_PROJECT_ID = "potent-howl-228108"
DEFAULT_COLLECTION = "users_2024"
EMAIL_FIELD = "מייל"


def normalize_email(value: object) -> str:
    return str(value or "").strip().casefold()


def initialize_firebase(project_id: str, credentials_path: Path | None):
    options = {"projectId": project_id}
    if credentials_path is not None:
        if not credentials_path.is_file():
            raise FileNotFoundError(
                f"Service-account file does not exist: {credentials_path}"
            )
        credential = credentials.Certificate(str(credentials_path))
        return firebase_admin.initialize_app(credential, options)

    # Uses GOOGLE_APPLICATION_CREDENTIALS or Application Default Credentials.
    return firebase_admin.initialize_app(options=options)


def load_active_users(db, collection: str) -> tuple[set[str], set[str]]:
    active_uids: set[str] = set()
    active_emails: set[str] = set()

    for document in db.collection(collection).stream():
        active_uids.add(document.id)
        email = normalize_email((document.to_dict() or {}).get(EMAIL_FIELD))
        if email:
            active_emails.add(email)

    return active_uids, active_emails


def find_orphans(
    app,
    active_uids: set[str],
    active_emails: set[str],
    include_no_email: bool,
    protected_emails: set[str],
) -> tuple[list, list]:
    orphaned_users = []
    skipped_without_email = []

    for user in auth.list_users(app=app).iterate_all():
        email = normalize_email(user.email)
        is_active = user.uid in active_uids or (email and email in active_emails)
        if is_active or email in protected_emails:
            continue

        if not email and not include_no_email:
            skipped_without_email.append(user)
            continue

        orphaned_users.append(user)

    return orphaned_users, skipped_without_email


def print_users(title: str, users: Iterable) -> None:
    users = list(users)
    print(f"\n{title}: {len(users)}")
    for user in users:
        print(f"  uid={user.uid}  email={user.email or '<no email>'}")


def confirm_deletion(project_id: str, count: int) -> bool:
    expected = f"DELETE {project_id} {count}"
    print("\nThis operation permanently deletes Firebase Authentication users.")
    print(f"Type exactly: {expected}")
    return input("> ").strip() == expected


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Delete Firebase Authentication users that have no matching "
            "document or email in Firestore users_2024."
        )
    )
    parser.add_argument("--project-id", default=DEFAULT_PROJECT_ID)
    parser.add_argument("--collection", default=DEFAULT_COLLECTION)
    parser.add_argument(
        "--credentials",
        type=Path,
        help=(
            "Path to a Firebase service-account JSON file. If omitted, "
            "Application Default Credentials are used."
        ),
    )
    parser.add_argument(
        "--protect-email",
        action="append",
        default=[],
        help="Email that must never be deleted. May be supplied more than once.",
    )
    parser.add_argument(
        "--include-no-email",
        action="store_true",
        help="Also treat Auth accounts without an email as deletion candidates.",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually delete the listed users. Without this flag, only report.",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip the interactive confirmation. Valid only with --execute.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.yes and not args.execute:
        print("--yes is valid only together with --execute", file=sys.stderr)
        return 2

    protected_emails = {
        normalize_email(email) for email in args.protect_email if email.strip()
    }

    try:
        app = initialize_firebase(args.project_id, args.credentials)
        db = firestore.client(app=app)
        active_uids, active_emails = load_active_users(db, args.collection)
        orphaned_users, skipped_without_email = find_orphans(
            app,
            active_uids,
            active_emails,
            args.include_no_email,
            protected_emails,
        )
    except Exception as error:
        print(f"Failed to scan Firebase: {error}", file=sys.stderr)
        return 1

    print(f"Project: {args.project_id}")
    print(f"Firestore collection: {args.collection}")
    print(f"Active Firestore UIDs: {len(active_uids)}")
    print(f"Active Firestore emails: {len(active_emails)}")
    print_users("Auth users without a Firestore match", orphaned_users)

    if skipped_without_email:
        print_users(
            "Skipped Auth users without email (use --include-no-email to include)",
            skipped_without_email,
        )

    if not orphaned_users:
        print("\nNothing to delete.")
        return 0

    if not args.execute:
        print("\nDry run only; no users were deleted.")
        print("Review the list, then rerun with --execute to delete it.")
        return 0

    if not args.yes and not confirm_deletion(args.project_id, len(orphaned_users)):
        print("Confirmation did not match. Nothing was deleted.")
        return 2

    deleted = 0
    failures = 0
    for user in orphaned_users:
        try:
            # Delete individually so Firebase Auth deletion triggers are preserved.
            auth.delete_user(user.uid, app=app)
            deleted += 1
            print(f"Deleted uid={user.uid} email={user.email or '<no email>'}")
        except Exception as error:
            failures += 1
            print(
                f"FAILED uid={user.uid} email={user.email or '<no email>'}: {error}",
                file=sys.stderr,
            )

    print(f"\nDeleted: {deleted}; failed: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
