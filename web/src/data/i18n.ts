export const languages = ["en", "es", "ca", "fr", "de"] as const

export type Language = (typeof languages)[number]

type Copy = {
  metaTitle: string
  metaDescription: string
  navFeatures: string
  navDemo: string
  navPrivacy: string
  navInstall: string
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
  demoTitle: string
  demoBody: string
  demoVideoLabel: string
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
  installTitle: string
  installBody: string
  directInstallLabel: string
  homebrewInstallLabel: string
  installNote: string
  installVideoLabel: string
}

export const copy: Record<Language, Copy> = {
  en: {
    metaTitle: "Settle - Switch between macOS window layouts",
    metaDescription:
      "Save complete Mac window layouts and switch between them in seconds with Option-Tab.",
    navFeatures: "Features",
    navDemo: "Demo",
    navPrivacy: "Privacy",
    navInstall: "Install",
    navDownload: "Download",
    heroEyebrow: "Menu bar app for macOS",
    heroTitle: "Switch layouts. Keep your flow.",
    heroBody:
      "Your work is more than one app. Save complete window layouts for coding, meetings, focus, or home, then move between them in seconds with Option-Tab.",
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
    demoTitle: "One shortcut. A complete context switch.",
    demoBody:
      "Hold Option-Tab, preview your active layouts, and release to bring every window into place.",
    demoVideoLabel: "Video showing Settle switching between complete window layouts with Option-Tab",
    supportTitle: "Work in layouts, not individual apps.",
    supportBody:
      "Settle turns each activity into a complete window setup while keeping the current macOS Space as the boundary.",
    supportOneTitle: "Capture the whole context",
    supportOneBody:
      "Save the visible apps, windows, sizes, positions, and layering in one action.",
    supportTwoTitle: "Switch with Option-Tab",
    supportTwoBody:
      "Preview active layouts, choose one from the keyboard, and restore the complete setup.",
    supportThreeTitle: "Handle extra windows your way",
    supportThreeBody:
      "Leave, minimize, or close unrelated visible windows after a successful restore.",
    workflowTitle: "A calmer reset for messy desktops.",
    workflowBody:
      "Use Settle after plugging into a display, returning from a meeting, or switching between deep work and review.",
    stepOne: "Save",
    stepTwo: "Name",
    stepThree: "Restore",
    detailTitle: "Native, transparent, and predictable.",
    detailBody:
      "Settle uses the macOS Accessibility API only to inspect visible windows and restore their frames.",
    detailOne: "Current macOS Space only",
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
      "Version 1.10.0 · universal DMG for Apple silicon and Intel · about 2.5 MB",
    trustLine:
      "Native macOS permissions. Layouts stay on your Mac.",
    midCtaTitle: "Ready when your desktop drifts.",
    requirementsTitle: "Requirements",
    requirementMinimum: "macOS 14.0 or later",
    requirementChip: "Apple silicon and Intel Macs",
    requirementSize: "DMG: about 2.5 MB",
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
    installTitle: "Install Settle on your Mac.",
    installBody:
      "Download the DMG or install Settle with Homebrew. Then open the app and complete the initial macOS setup.",
    directInstallLabel: "Direct download",
    homebrewInstallLabel: "Homebrew",
    installNote: "On first launch, grant Accessibility permission so Settle can restore window positions.",
    installVideoLabel: "Video showing how to install and set up Settle",
  },
  es: {
    metaTitle: "Settle - Cambia entre layouts de ventanas en macOS",
    metaDescription:
      "Guarda layouts completos de ventanas del Mac y cambia entre ellos en segundos con Opción-Tab.",
    navFeatures: "Funciones",
    navDemo: "Demo",
    navPrivacy: "Privacidad",
    navInstall: "Instalación",
    navDownload: "Descargar",
    heroEyebrow: "App de barra de menús para macOS",
    heroTitle: "Cambia de layout. Mantén el ritmo.",
    heroBody:
      "Tu trabajo es más que una app. Guarda layouts completos para programar, reunirte, concentrarte o estar en casa y cambia entre ellos en segundos con Opción-Tab.",
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
    demoTitle: "Un atajo. Un cambio de contexto completo.",
    demoBody:
      "Mantén Opción-Tab, previsualiza tus layouts activos y suelta para devolver cada ventana a su sitio.",
    demoVideoLabel: "Vídeo de Settle cambiando entre layouts completos con Opción-Tab",
    supportTitle: "Trabaja con layouts, no con apps aisladas.",
    supportBody:
      "Settle convierte cada actividad en una configuración completa de ventanas y mantiene el Space actual de macOS como límite.",
    supportOneTitle: "Captura todo el contexto",
    supportOneBody:
      "Guarda apps visibles, ventanas, tamaños, posiciones y capas en una sola acción.",
    supportTwoTitle: "Cambia con Opción-Tab",
    supportTwoBody:
      "Previsualiza los layouts activos, elige uno con el teclado y restaura toda la configuración.",
    supportThreeTitle: "Gestiona las ventanas extra a tu manera",
    supportThreeBody:
      "Déjalas intactas, minimízalas o ciérralas tras restaurar correctamente un layout.",
    workflowTitle: "Un reinicio más limpio para escritorios desordenados.",
    workflowBody:
      "Usa Settle al conectar una pantalla, volver de una reunión o cambiar entre foco y revisión.",
    stepOne: "Guarda",
    stepTwo: "Nombra",
    stepThree: "Restaura",
    detailTitle: "Nativa, transparente y predecible.",
    detailBody:
      "Settle usa la API de Accesibilidad de macOS solo para inspeccionar ventanas visibles y restaurar sus marcos.",
    detailOne: "Solo el Space actual de macOS",
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
      "Versión 1.10.0 · DMG universal para Apple silicon e Intel · alrededor de 2,5 MB",
    trustLine:
      "Permisos nativos de macOS. Los layouts se quedan en tu Mac.",
    midCtaTitle: "Listo cuando tu escritorio se desordena.",
    requirementsTitle: "Requisitos",
    requirementMinimum: "macOS 14.0 o posterior",
    requirementChip: "Macs Apple silicon e Intel",
    requirementSize: "DMG: alrededor de 2,5 MB",
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
    installTitle: "Instala Settle en tu Mac.",
    installBody:
      "Descarga el DMG o instala Settle con Homebrew. Después abre la app y completa la configuración inicial de macOS.",
    directInstallLabel: "Descarga directa",
    homebrewInstallLabel: "Homebrew",
    installNote: "En el primer inicio, concede permiso de Accesibilidad para que Settle pueda restaurar las ventanas.",
    installVideoLabel: "Vídeo del proceso de instalación y configuración de Settle",
  },
  ca: {
    metaTitle: "Settle - Canvia entre layouts de finestres a macOS",
    metaDescription:
      "Desa layouts complets de finestres del Mac i canvia entre ells en segons amb Opció-Tab.",
    navFeatures: "Funcions",
    navDemo: "Demo",
    navPrivacy: "Privacitat",
    navInstall: "Instal·lació",
    navDownload: "Descarrega",
    heroEyebrow: "App de barra de menús per a macOS",
    heroTitle: "Canvia de layout. Mantén el ritme.",
    heroBody:
      "La teva feina és més que una app. Desa layouts complets per programar, reunir-te, concentrar-te o ser a casa i canvia entre ells en segons amb Opció-Tab.",
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
    demoTitle: "Una drecera. Un canvi de context complet.",
    demoBody:
      "Mantén Opció-Tab, previsualitza els layouts actius i deixa anar les tecles per tornar cada finestra al seu lloc.",
    demoVideoLabel: "Vídeo de Settle canviant entre layouts complets amb Opció-Tab",
    supportTitle: "Treballa amb layouts, no amb apps aïllades.",
    supportBody:
      "Settle converteix cada activitat en una configuració completa de finestres i manté l’Space actual de macOS com a límit.",
    supportOneTitle: "Captura tot el context",
    supportOneBody:
      "Desa apps visibles, finestres, mides, posicions i capes en una sola acció.",
    supportTwoTitle: "Canvia amb Opció-Tab",
    supportTwoBody:
      "Previsualitza els layouts actius, tria'n un amb el teclat i restaura tota la configuració.",
    supportThreeTitle: "Gestiona les finestres extra a la teva manera",
    supportThreeBody:
      "Deixa-les intactes, minimitza-les o tanca-les després de restaurar correctament un layout.",
    workflowTitle: "Un reinici més net per a escriptoris desordenats.",
    workflowBody:
      "Fes servir Settle en connectar una pantalla, tornar d’una reunió o canviar entre focus i revisió.",
    stepOne: "Desa",
    stepTwo: "Anomena",
    stepThree: "Restaura",
    detailTitle: "Nativa, transparent i previsible.",
    detailBody:
      "Settle usa l’API d’Accessibilitat de macOS només per inspeccionar finestres visibles i restaurar-ne els marcs.",
    detailOne: "Només l’Space actual de macOS",
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
      "Versió 1.10.0 · DMG universal per a Apple silicon i Intel · prop de 2,5 MB",
    trustLine:
      "Permisos natius de macOS. Els layouts es queden al Mac.",
    midCtaTitle: "A punt quan l’escriptori es desordena.",
    requirementsTitle: "Requisits",
    requirementMinimum: "macOS 14.0 o posterior",
    requirementChip: "Macs Apple silicon i Intel",
    requirementSize: "DMG: prop de 2,5 MB",
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
    installTitle: "Instal·la Settle al Mac.",
    installBody:
      "Descarrega el DMG o instal·la Settle amb Homebrew. Després obre l’app i completa la configuració inicial de macOS.",
    directInstallLabel: "Descàrrega directa",
    homebrewInstallLabel: "Homebrew",
    installNote: "En el primer inici, concedeix permís d’Accessibilitat perquè Settle pugui restaurar les finestres.",
    installVideoLabel: "Vídeo del procés d’instal·lació i configuració de Settle",
  },
  fr: {
    metaTitle: "Settle - Passer d’un agencement de fenêtres à l’autre sur macOS",
    metaDescription:
      "Enregistrez des agencements complets de fenêtres Mac et passez de l’un à l’autre en quelques secondes avec Option-Tab.",
    navFeatures: "Fonctions",
    navDemo: "Démo",
    navPrivacy: "Confidentialité",
    navInstall: "Installation",
    navDownload: "Télécharger",
    heroEyebrow: "App de barre des menus pour macOS",
    heroTitle: "Changez d’agencement. Gardez votre rythme.",
    heroBody:
      "Votre travail ne se limite pas à une app. Enregistrez des agencements complets pour coder, vous réunir ou vous concentrer, puis passez de l’un à l’autre avec Option-Tab.",
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
    demoTitle: "Un raccourci. Un changement de contexte complet.",
    demoBody:
      "Maintenez Option-Tab, prévisualisez vos agencements actifs, puis relâchez pour remettre chaque fenêtre à sa place.",
    demoVideoLabel: "Vidéo de Settle passant d’un agencement complet à l’autre avec Option-Tab",
    supportTitle: "Travaillez par agencements, pas par apps isolées.",
    supportBody:
      "Settle transforme chaque activité en une configuration complète de fenêtres, limitée au Space macOS actuel.",
    supportOneTitle: "Capturez tout le contexte",
    supportOneBody:
      "Enregistrez les apps visibles, les fenêtres, les tailles, les positions et leur ordre en une action.",
    supportTwoTitle: "Passez de l’un à l’autre avec Option-Tab",
    supportTwoBody:
      "Prévisualisez les agencements actifs, choisissez au clavier et restaurez toute la configuration.",
    supportThreeTitle: "Gérez les fenêtres supplémentaires à votre façon",
    supportThreeBody:
      "Laissez, réduisez ou fermez les fenêtres visibles non liées après une restauration réussie.",
    workflowTitle: "Une remise en ordre plus calme pour les bureaux chargés.",
    workflowBody:
      "Utilisez Settle après avoir branché un écran, au retour d’une réunion ou en changeant de mode de travail.",
    stepOne: "Enregistrer",
    stepTwo: "Nommer",
    stepThree: "Restaurer",
    detailTitle: "Native, transparente et prévisible.",
    detailBody:
      "Settle utilise l’API Accessibilité de macOS uniquement pour inspecter les fenêtres visibles et restaurer leur cadre.",
    detailOne: "Space macOS actuel uniquement",
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
      "Version 1.10.0 · DMG universel Apple silicon et Intel · environ 2,5 Mo",
    trustLine:
      "Autorisations natives de macOS. Les agencements restent sur votre Mac.",
    midCtaTitle: "Prête quand votre bureau se dérange.",
    requirementsTitle: "Prérequis",
    requirementMinimum: "macOS 14.0 ou plus récent",
    requirementChip: "Mac Apple silicon et Intel",
    requirementSize: "DMG : environ 2,5 Mo",
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
    installTitle: "Installez Settle sur votre Mac.",
    installBody:
      "Téléchargez le DMG ou installez Settle avec Homebrew. Ouvrez ensuite l’app et terminez la configuration initiale de macOS.",
    directInstallLabel: "Téléchargement direct",
    homebrewInstallLabel: "Homebrew",
    installNote: "Au premier lancement, accordez l’autorisation Accessibilité pour permettre à Settle de restaurer les fenêtres.",
    installVideoLabel: "Vidéo du processus d’installation et de configuration de Settle",
  },
  de: {
    metaTitle: "Settle - Zwischen macOS-Fensterlayouts wechseln",
    metaDescription:
      "Speichere vollständige Mac-Fensterlayouts und wechsle mit Wahltaste-Tab in Sekunden zwischen ihnen.",
    navFeatures: "Funktionen",
    navDemo: "Demo",
    navPrivacy: "Datenschutz",
    navInstall: "Installation",
    navDownload: "Download",
    heroEyebrow: "Menüleisten-App für macOS",
    heroTitle: "Layout wechseln. Im Flow bleiben.",
    heroBody:
      "Deine Arbeit ist mehr als eine App. Speichere vollständige Layouts fürs Programmieren, Meetings oder fokussiertes Arbeiten und wechsle mit Wahltaste-Tab zwischen ihnen.",
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
    demoTitle: "Ein Kurzbefehl. Ein vollständiger Kontextwechsel.",
    demoBody:
      "Halte Wahltaste-Tab, sieh aktive Layouts in der Vorschau und lasse los, um jedes Fenster an seinen Platz zu bringen.",
    demoVideoLabel: "Video von Settle beim Wechsel zwischen vollständigen Layouts mit Wahltaste-Tab",
    supportTitle: "In Layouts arbeiten, nicht in einzelnen Apps.",
    supportBody:
      "Settle macht aus jeder Tätigkeit eine vollständige Fensteranordnung und bleibt dabei im aktuellen macOS Space.",
    supportOneTitle: "Den ganzen Kontext erfassen",
    supportOneBody:
      "Sichtbare Apps, Fenster, Größen, Positionen und Ebenen mit einer Aktion speichern.",
    supportTwoTitle: "Mit Wahltaste-Tab wechseln",
    supportTwoBody:
      "Aktive Layouts ansehen, per Tastatur auswählen und die gesamte Anordnung wiederherstellen.",
    supportThreeTitle: "Zusätzliche Fenster nach Wunsch behandeln",
    supportThreeBody:
      "Nicht zugehörige sichtbare Fenster nach erfolgreicher Wiederherstellung belassen, minimieren oder schließen.",
    workflowTitle: "Ein ruhiger Reset für unordentliche Schreibtische.",
    workflowBody:
      "Nutze Settle nach dem Anschließen eines Displays, nach Meetings oder beim Wechsel zwischen Fokus und Review.",
    stepOne: "Speichern",
    stepTwo: "Benennen",
    stepThree: "Wiederherstellen",
    detailTitle: "Nativ, transparent und vorhersehbar.",
    detailBody:
      "Settle nutzt die macOS-API für Bedienungshilfen nur, um sichtbare Fenster zu prüfen und ihre Rahmen wiederherzustellen.",
    detailOne: "Nur aktueller macOS Space",
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
      "Version 1.10.0 · universelles DMG für Apple Silicon und Intel · etwa 2,5 MB",
    trustLine:
      "Native macOS-Berechtigungen. Layouts bleiben auf deinem Mac.",
    midCtaTitle: "Bereit, wenn dein Schreibtisch aus dem Takt gerät.",
    requirementsTitle: "Voraussetzungen",
    requirementMinimum: "macOS 14.0 oder neuer",
    requirementChip: "Apple-Silicon- und Intel-Macs",
    requirementSize: "DMG: etwa 2,5 MB",
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
    installTitle: "Settle auf deinem Mac installieren.",
    installBody:
      "Lade das DMG herunter oder installiere Settle mit Homebrew. Öffne danach die App und schließe die macOS-Ersteinrichtung ab.",
    directInstallLabel: "Direkter Download",
    homebrewInstallLabel: "Homebrew",
    installNote: "Erteile beim ersten Start die Berechtigung für Bedienungshilfen, damit Settle Fenster wiederherstellen kann.",
    installVideoLabel: "Video zur Installation und Einrichtung von Settle",
  },
}

export const defaultLanguage: Language = "en"

export function isLanguage(value: string | undefined): value is Language {
  return Boolean(value && languages.includes(value as Language))
}
