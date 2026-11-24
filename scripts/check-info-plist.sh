#!/bin/sh
# Vérifie l'Info.plist de l'app avant un envoi : chaque texte d'autorisation est présent et non vide, et le mode d'arrière-plan
# workout-processing, refusé par App Store Connect, n'y est pas. Usage : scripts/check-info-plist.sh [chemin], Pulse/Info.plist
# par défaut. Code 1 dès qu'un écart est trouvé, chacun avec son message.

plist="${1:-Pulse/Info.plist}"
buddy=/usr/libexec/PlistBuddy

if [ ! -f "$plist" ]; then
	echo "erreur : $plist est introuvable." >&2
	exit 1
fi

status=0
for key in NSCameraUsageDescription NSFaceIDUsageDescription NSPhotoLibraryAddUsageDescription \
	NSHealthShareUsageDescription NSHealthUpdateUsageDescription NSLocationWhenInUseUsageDescription; do
	value=$("$buddy" -c "Print :$key" "$plist" 2>/dev/null)
	if [ -z "$(printf '%s' "$value" | tr -d '[:space:]')" ]; then
		echo "erreur : la clé $key manque ou est vide dans $plist." >&2
		status=1
	fi
done

# Une entrée par ligne entre les accolades de PlistBuddy ; absente, la liste est vide.
modes=$("$buddy" -c "Print :UIBackgroundModes" "$plist" 2>/dev/null)
if printf '%s\n' "$modes" | grep -qx '[[:space:]]*workout-processing[[:space:]]*'; then
	echo "erreur : UIBackgroundModes contient workout-processing, qu'App Store Connect refuse." >&2
	status=1
fi

exit $status
