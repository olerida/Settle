export const languages = ["en", "es", "ca", "fr", "de"] as const

export type Language = (typeof languages)[number]

type Copy = {
  metaTitle: string
  metaDescription: string
  navFeatures: string
  navPrivacy: string
  navDownload: string
  heroEyebrow: string
  heroTitle: string
  heroBody: string
  primaryCta: string
  secondaryCta: string
  visualTitle: string
  visualSubtitle: string
  visualSave: string
  visualRestore: string
  visualStatus: string
  visualItemOne: string
  visualItemTwo: string
  visualFourApps: string
  visualSixApps: string
  screenshotAlt: string
  supportTitle: string
  supportBody: string
  supportOneTitle: string
  supportOneBody: string
  supportTwoTitle: string
  supportTwoBody: string
  supportThreeTitle: string
  supportThreeBody: string
  workflowTitle: string
  workflowBody: string
  stepOne: string
  stepTwo: string
  stepThree: string
  detailTitle: string
  detailBody: string
  detailOne: string
  detailTwo: string
  detailThree: string
  privacyTitle: string
  privacyBody: string
  finalTitle: string
  finalBody: string
  footer: string
  languageLabel: string
  downloadMeta: string
  trustLine: string
  midCtaTitle: string
  requirementsTitle: string
  requirementMinimum: string
  requirementChip: string
  requirementSize: string
  requirementSignature: string
  accessibilityTitle: string
  accessibilityBody: string
  accessibilityDoes: string
  accessibilityDoesNot: string
  sourceTitle: string
  sourceBody: string
}

export const copy: Record<Language, Copy> = {
  en: {
    metaTitle: "Settle - Save and restore macOS window layouts",
    metaDescription:
      "Settle is a lightweight macOS menu bar app that saves and restores window layouts on the current desktop.",
    navFeatures: "Features",
    navPrivacy: "Privacy",
    navDownload: "Download",
    heroEyebrow: "Menu bar app for macOS",
    heroTitle: "Put every window back where it belongs.",
    heroBody:
      "Settle saves the size and position of your visible windows, then restores that layout when your desk needs to feel familiar again.",
    primaryCta: "Download for macOS",
    secondaryCta: "View source",
    visualTitle: "Current desktop",
    visualSubtitle: "Window layouts",
    visualSave: "Save Layout",
    visualRestore: "Restore",
    visualStatus: "Ready",
    visualItemOne: "Morning focus",
    visualItemTwo: "Design review",
    visualFourApps: "4 apps",
    visualSixApps: "6 apps",
    screenshotAlt: "Settle menu showing saved window layouts",
    supportTitle: "Built for the way macOS already works.",
    supportBody:
      "Settle stays in the menu bar, uses native permissions, and keeps the current desktop as the boundary.",
    supportOneTitle: "Save the current layout",
    supportOneBody:
      "Capture visible app windows, their sizes, and their positions in one action.",
    supportTwoTitle: "Restore with intent",
    supportTwoBody:
      "Reopen apps when possible and move windows back into place using Accessibility.",
    supportThreeTitle: "Leave extra windows alone",
    supportThreeBody:
      "Does not close, hide, or minimize windows outside the selected layout.",
    workflowTitle: "A calmer reset for messy desktops.",
    workflowBody:
      "Use Settle after plugging into a display, returning from a meeting, or switching between deep work and review.",
    stepOne: "Save",
    stepTwo: "Name",
    stepThree: "Restore",
    detailTitle: "Native, transparent, and predictable.",
    detailBody:
      "Settle uses the macOS Accessibility API only to inspect visible windows and restore their frames.",
    detailOne: "Current desktop only",
    detailTwo: "Accessibility permission required",
    detailThree: "Unresolved windows are reported",
    privacyTitle: "Privacy",
    privacyBody:
      "Your layouts stay on your Mac. The app does not need an account to save or restore windows.",
    finalTitle: "Make your Mac return to shape.",
    finalBody:
      "A small utility for people who care where their work lives on screen.",
    footer: "Settle for macOS",
    languageLabel: "Languages",
    downloadMeta:
      "Version 1.0 · universal DMG for Apple silicon and Intel · about 1 MB",
    trustLine:
      "Settle uses native macOS permissions, keeps layouts on your Mac, and makes the code available for review.",
    midCtaTitle: "Ready when your desktop drifts.",
    requirementsTitle: "Requirements",
    requirementMinimum: "macOS 14.0 or later",
    requirementChip: "Apple silicon and Intel Macs",
    requirementSize: "DMG: about 1 MB",
    requirementSignature: "Security and transparency",
    accessibilityTitle: "Why Accessibility permission is needed",
    accessibilityBody:
      "Settle uses macOS Accessibility to read visible window frames and move those windows back into place.",
    accessibilityDoes:
      "It reads window titles, app names, positions, and sizes.",
    accessibilityDoesNot:
      "It does not read document contents, keystrokes, passwords, or browser pages.",
    sourceTitle: "Open source for transparency",
    sourceBody:
      "The code is public on GitHub, so the permission model and restore logic can be inspected.",
  },
  es: {
    metaTitle: "Settle - Guarda y restaura layouts de ventanas en macOS",
    metaDescription:
      "Settle es una app ligera de barra de menús para macOS que guarda y restaura layouts de ventanas del escritorio actual.",
    navFeatures: "Funciones",
    navPrivacy: "Privacidad",
    navDownload: "Descargar",
    heroEyebrow: "App de barra de menús para macOS",
    heroTitle: "Devuelve cada ventana a su sitio.",
    heroBody:
      "Settle guarda el tamaño y la posición de tus ventanas visibles y restaura ese layout cuando necesitas recuperar tu mesa de trabajo.",
    primaryCta: "Descargar para macOS",
    secondaryCta: "Ver código",
    visualTitle: "Escritorio actual",
    visualSubtitle: "Layouts de ventanas",
    visualSave: "Guardar layout",
    visualRestore: "Restaurar",
    visualStatus: "Listo",
    visualItemOne: "Foco de mañana",
    visualItemTwo: "Revisión de diseño",
    visualFourApps: "4 apps",
    visualSixApps: "6 apps",
    screenshotAlt: "Menú de Settle mostrando layouts de ventanas guardados",
    supportTitle: "Pensada para cómo macOS ya funciona.",
    supportBody:
      "Settle vive en la barra de menús, usa permisos nativos y toma el escritorio actual como límite.",
    supportOneTitle: "Guarda el layout actual",
    supportOneBody:
      "Captura ventanas visibles, tamaños y posiciones en una sola acción.",
    supportTwoTitle: "Restaura con intención",
    supportTwoBody:
      "Reabre apps cuando es posible y recoloca ventanas mediante Accesibilidad.",
    supportThreeTitle: "Deja intactas las ventanas extra",
    supportThreeBody:
      "No cierra, oculta ni minimiza ventanas fuera del layout seleccionado.",
    workflowTitle: "Un reinicio más limpio para escritorios desordenados.",
    workflowBody:
      "Usa Settle al conectar una pantalla, volver de una reunión o cambiar entre foco y revisión.",
    stepOne: "Guarda",
    stepTwo: "Nombra",
    stepThree: "Restaura",
    detailTitle: "Nativa, transparente y predecible.",
    detailBody:
      "Settle usa la API de Accesibilidad de macOS solo para inspeccionar ventanas visibles y restaurar sus marcos.",
    detailOne: "Solo escritorio actual",
    detailTwo: "Requiere permiso de Accesibilidad",
    detailThree: "Informa ventanas no resueltas",
    privacyTitle: "Privacidad",
    privacyBody:
      "Tus layouts se quedan en tu Mac. La app no necesita una cuenta para guardar o restaurar ventanas.",
    finalTitle: "Haz que tu Mac vuelva a su forma.",
    finalBody:
      "Una utilidad pequeña para quien cuida dónde vive su trabajo en pantalla.",
    footer: "Settle para macOS",
    languageLabel: "Idiomas",
    downloadMeta:
      "Versión 1.0 · DMG universal para Apple silicon e Intel · alrededor de 1 MB",
    trustLine:
      "Settle usa permisos nativos de macOS, guarda los layouts en tu Mac y mantiene el código disponible para revisión.",
    midCtaTitle: "Listo cuando tu escritorio se desordena.",
    requirementsTitle: "Requisitos",
    requirementMinimum: "macOS 14.0 o posterior",
    requirementChip: "Macs Apple silicon e Intel",
    requirementSize: "DMG: alrededor de 1 MB",
    requirementSignature: "Seguridad y transparencia",
    accessibilityTitle: "Por qué necesita permiso de Accesibilidad",
    accessibilityBody:
      "Settle usa Accesibilidad de macOS para leer los marcos de las ventanas visibles y devolverlas a su sitio.",
    accessibilityDoes:
      "Lee títulos de ventanas, nombres de apps, posiciones y tamaños.",
    accessibilityDoesNot:
      "No lee contenido de documentos, teclas, contraseñas ni páginas del navegador.",
    sourceTitle: "Código abierto para mayor transparencia",
    sourceBody:
      "El código está publicado en GitHub, así que se puede revisar el uso de permisos y la lógica de restauración.",
  },
  ca: {
    metaTitle: "Settle - Desa i restaura layouts de finestres a macOS",
    metaDescription:
      "Settle és una app lleugera de barra de menús per a macOS que desa i restaura layouts de finestres de l’escriptori actual.",
    navFeatures: "Funcions",
    navPrivacy: "Privacitat",
    navDownload: "Descarrega",
    heroEyebrow: "App de barra de menús per a macOS",
    heroTitle: "Torna cada finestra al seu lloc.",
    heroBody:
      "Settle desa la mida i la posició de les finestres visibles i restaura aquest layout quan necessites recuperar l’espai de treball.",
    primaryCta: "Descarrega per a macOS",
    secondaryCta: "Veure codi",
    visualTitle: "Escriptori actual",
    visualSubtitle: "Layouts de finestres",
    visualSave: "Desa layout",
    visualRestore: "Restaura",
    visualStatus: "A punt",
    visualItemOne: "Focus del matí",
    visualItemTwo: "Revisió de disseny",
    visualFourApps: "4 apps",
    visualSixApps: "6 apps",
    screenshotAlt: "Menú de Settle amb layouts de finestres desats",
    supportTitle: "Feta per a la manera com macOS ja funciona.",
    supportBody:
      "Settle viu a la barra de menús, usa permisos natius i pren l’escriptori actual com a límit.",
    supportOneTitle: "Desa el layout actual",
    supportOneBody:
      "Captura finestres visibles, mides i posicions en una sola acció.",
    supportTwoTitle: "Restaura amb intenció",
    supportTwoBody:
      "Reobre apps quan és possible i recol·loca finestres amb Accessibilitat.",
    supportThreeTitle: "Deixa intactes les finestres extra",
    supportThreeBody:
      "No tanca, amaga ni minimitza finestres fora del layout seleccionat.",
    workflowTitle: "Un reinici més net per a escriptoris desordenats.",
    workflowBody:
      "Fes servir Settle en connectar una pantalla, tornar d’una reunió o canviar entre focus i revisió.",
    stepOne: "Desa",
    stepTwo: "Anomena",
    stepThree: "Restaura",
    detailTitle: "Nativa, transparent i previsible.",
    detailBody:
      "Settle usa l’API d’Accessibilitat de macOS només per inspeccionar finestres visibles i restaurar-ne els marcs.",
    detailOne: "Només escriptori actual",
    detailTwo: "Cal permís d’Accessibilitat",
    detailThree: "Informa finestres no resoltes",
    privacyTitle: "Privacitat",
    privacyBody:
      "Els teus layouts es queden al Mac. L’app no necessita cap compte per desar o restaurar finestres.",
    finalTitle: "Fes que el Mac torni a la seva forma.",
    finalBody:
      "Una utilitat petita per a qui cuida on viu la feina a la pantalla.",
    footer: "Settle per a macOS",
    languageLabel: "Idiomes",
    downloadMeta:
      "Versió 1.0 · DMG universal per a Apple silicon i Intel · prop d’1 MB",
    trustLine:
      "Settle usa permisos natius de macOS, desa els layouts al Mac i manté el codi disponible per revisar-lo.",
    midCtaTitle: "A punt quan l’escriptori es desordena.",
    requirementsTitle: "Requisits",
    requirementMinimum: "macOS 14.0 o posterior",
    requirementChip: "Macs Apple silicon i Intel",
    requirementSize: "DMG: prop d’1 MB",
    requirementSignature: "Seguretat i transparència",
    accessibilityTitle: "Per què necessita permís d’Accessibilitat",
    accessibilityBody:
      "Settle usa Accessibilitat de macOS per llegir els marcs de les finestres visibles i tornar-les al seu lloc.",
    accessibilityDoes:
      "Llegeix títols de finestres, noms d’apps, posicions i mides.",
    accessibilityDoesNot:
      "No llegeix contingut de documents, tecles, contrasenyes ni pàgines del navegador.",
    sourceTitle: "Codi obert per a més transparència",
    sourceBody:
      "El codi és públic a GitHub, així es pot revisar l’ús dels permisos i la lògica de restauració.",
  },
  fr: {
    metaTitle: "Settle - Enregistrer et restaurer les fenêtres sur macOS",
    metaDescription:
      "Settle est une app légère de barre des menus pour macOS qui enregistre et restaure les agencements de fenêtres du bureau actuel.",
    navFeatures: "Fonctions",
    navPrivacy: "Confidentialité",
    navDownload: "Télécharger",
    heroEyebrow: "App de barre des menus pour macOS",
    heroTitle: "Remettez chaque fenêtre à sa place.",
    heroBody:
      "Settle enregistre la taille et la position de vos fenêtres visibles, puis restaure cet agencement quand votre bureau doit redevenir familier.",
    primaryCta: "Télécharger pour macOS",
    secondaryCta: "Voir le code",
    visualTitle: "Bureau actuel",
    visualSubtitle: "Agencements de fenêtres",
    visualSave: "Enregistrer",
    visualRestore: "Restaurer",
    visualStatus: "Prêt",
    visualItemOne: "Concentration du matin",
    visualItemTwo: "Revue design",
    visualFourApps: "4 apps",
    visualSixApps: "6 apps",
    screenshotAlt:
      "Menu Settle affichant des agencements de fenêtres enregistrés",
    supportTitle: "Pensée pour la façon dont macOS fonctionne déjà.",
    supportBody:
      "Settle reste dans la barre des menus, utilise les autorisations natives et limite son action au bureau actuel.",
    supportOneTitle: "Enregistrez l’agencement actuel",
    supportOneBody:
      "Capturez les fenêtres visibles, leurs tailles et leurs positions en une action.",
    supportTwoTitle: "Restaurez avec précision",
    supportTwoBody:
      "Rouvrez les apps quand c’est possible et replacez les fenêtres avec Accessibilité.",
    supportThreeTitle: "Laissez les fenêtres en plus tranquilles",
    supportThreeBody:
      "Ne ferme, ne masque ni ne minimise les fenêtres hors de l’agencement sélectionné.",
    workflowTitle: "Une remise en ordre plus calme pour les bureaux chargés.",
    workflowBody:
      "Utilisez Settle après avoir branché un écran, au retour d’une réunion ou en changeant de mode de travail.",
    stepOne: "Enregistrer",
    stepTwo: "Nommer",
    stepThree: "Restaurer",
    detailTitle: "Native, transparente et prévisible.",
    detailBody:
      "Settle utilise l’API Accessibilité de macOS uniquement pour inspecter les fenêtres visibles et restaurer leur cadre.",
    detailOne: "Bureau actuel uniquement",
    detailTwo: "Autorisation Accessibilité requise",
    detailThree: "Fenêtres non résolues signalées",
    privacyTitle: "Confidentialité",
    privacyBody:
      "Vos agencements restent sur votre Mac. L’app n’a pas besoin de compte pour enregistrer ou restaurer les fenêtres.",
    finalTitle: "Redonnez sa forme à votre Mac.",
    finalBody:
      "Un petit utilitaire pour celles et ceux qui soignent la place de leur travail à l’écran.",
    footer: "Settle pour macOS",
    languageLabel: "Langues",
    downloadMeta:
      "Version 1.0 · DMG universel Apple silicon et Intel · environ 1 Mo",
    trustLine:
      "Settle utilise les permissions natives de macOS, garde les agencements sur votre Mac et rend le code disponible à la vérification.",
    midCtaTitle: "Prête quand votre bureau se dérange.",
    requirementsTitle: "Prérequis",
    requirementMinimum: "macOS 14.0 ou plus récent",
    requirementChip: "Mac Apple silicon et Intel",
    requirementSize: "DMG : environ 1 Mo",
    requirementSignature: "Sécurité et transparence",
    accessibilityTitle: "Pourquoi l’autorisation Accessibilité est nécessaire",
    accessibilityBody:
      "Settle utilise Accessibilité macOS pour lire les cadres des fenêtres visibles et les remettre en place.",
    accessibilityDoes:
      "Lit les titres de fenêtres, noms d’apps, positions et tailles.",
    accessibilityDoesNot:
      "Ne lit pas le contenu des documents, frappes, mots de passe ni pages web.",
    sourceTitle: "Open source pour la transparence",
    sourceBody:
      "Le code est public sur GitHub, ce qui permet de vérifier les permissions et la logique de restauration.",
  },
  de: {
    metaTitle: "Settle - macOS-Fensterlayouts speichern und wiederherstellen",
    metaDescription:
      "Settle ist eine leichte Menüleisten-App für macOS, die Fensterlayouts des aktuellen Schreibtischs speichert und wiederherstellt.",
    navFeatures: "Funktionen",
    navPrivacy: "Datenschutz",
    navDownload: "Download",
    heroEyebrow: "Menüleisten-App für macOS",
    heroTitle: "Jedes Fenster zurück an seinen Platz.",
    heroBody:
      "Settle speichert Größe und Position deiner sichtbaren Fenster und stellt dieses Layout wieder her, wenn dein Schreibtisch vertraut wirken soll.",
    primaryCta: "Für macOS laden",
    secondaryCta: "Quellcode",
    visualTitle: "Aktueller Schreibtisch",
    visualSubtitle: "Fensterlayouts",
    visualSave: "Layout speichern",
    visualRestore: "Wiederherstellen",
    visualStatus: "Bereit",
    visualItemOne: "Morgenfokus",
    visualItemTwo: "Design-Review",
    visualFourApps: "4 Apps",
    visualSixApps: "6 Apps",
    screenshotAlt: "Settle-Menü mit gespeicherten Fensterlayouts",
    supportTitle: "Gemacht für die Art, wie macOS bereits funktioniert.",
    supportBody:
      "Settle bleibt in der Menüleiste, nutzt native Berechtigungen und behandelt den aktuellen Schreibtisch als Grenze.",
    supportOneTitle: "Aktuelles Layout speichern",
    supportOneBody:
      "Sichtbare App-Fenster, Größen und Positionen mit einer Aktion erfassen.",
    supportTwoTitle: "Gezielt wiederherstellen",
    supportTwoBody:
      "Apps nach Möglichkeit erneut öffnen und Fenster per Bedienungshilfen zurücksetzen.",
    supportThreeTitle: "Zusätzliche Fenster bleiben unberührt",
    supportThreeBody:
      "Schließt, versteckt oder minimiert keine Fenster außerhalb des gewählten Layouts.",
    workflowTitle: "Ein ruhiger Reset für unordentliche Schreibtische.",
    workflowBody:
      "Nutze Settle nach dem Anschließen eines Displays, nach Meetings oder beim Wechsel zwischen Fokus und Review.",
    stepOne: "Speichern",
    stepTwo: "Benennen",
    stepThree: "Wiederherstellen",
    detailTitle: "Nativ, transparent und vorhersehbar.",
    detailBody:
      "Settle nutzt die macOS-API für Bedienungshilfen nur, um sichtbare Fenster zu prüfen und ihre Rahmen wiederherzustellen.",
    detailOne: "Nur aktueller Schreibtisch",
    detailTwo: "Berechtigung für Bedienungshilfen erforderlich",
    detailThree: "Nicht aufgelöste Fenster werden gemeldet",
    privacyTitle: "Datenschutz",
    privacyBody:
      "Deine Layouts bleiben auf deinem Mac. Die App braucht kein Konto, um Fenster zu speichern oder wiederherzustellen.",
    finalTitle: "Bring deinen Mac wieder in Form.",
    finalBody:
      "Ein kleines Werkzeug für Menschen, denen wichtig ist, wo ihre Arbeit auf dem Bildschirm liegt.",
    footer: "Settle für macOS",
    languageLabel: "Sprachen",
    downloadMeta:
      "Version 1.0 · universelles DMG für Apple Silicon und Intel · etwa 1 MB",
    trustLine:
      "Settle nutzt native macOS-Berechtigungen, speichert Layouts auf deinem Mac und stellt den Code zur Prüfung bereit.",
    midCtaTitle: "Bereit, wenn dein Schreibtisch aus dem Takt gerät.",
    requirementsTitle: "Voraussetzungen",
    requirementMinimum: "macOS 14.0 oder neuer",
    requirementChip: "Apple-Silicon- und Intel-Macs",
    requirementSize: "DMG: etwa 1 MB",
    requirementSignature: "Sicherheit und Transparenz",
    accessibilityTitle: "Warum Bedienungshilfen benötigt werden",
    accessibilityBody:
      "Settle nutzt macOS-Bedienungshilfen, um sichtbare Fensterrahmen zu lesen und Fenster zurückzusetzen.",
    accessibilityDoes: "Liest Fenstertitel, App-Namen, Positionen und Größen.",
    accessibilityDoesNot:
      "Liest keine Dokumentinhalte, Tastatureingaben, Passwörter oder Browserseiten.",
    sourceTitle: "Open Source für Transparenz",
    sourceBody:
      "Der Code ist auf GitHub öffentlich, damit Berechtigungen und Wiederherstellungslogik geprüft werden können.",
  },
}

export const defaultLanguage: Language = "en"

export function isLanguage(value: string | undefined): value is Language {
  return Boolean(value && languages.includes(value as Language))
}
