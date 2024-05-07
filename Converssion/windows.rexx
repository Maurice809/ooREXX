::requires "ooDialog.cls"

::class MaFenetre sous OODIALOG
::method init
    expose maFenetre
    self~init:super()
    maFenetre = self~new("Fenêtre", "titre_de_ma_fenetre", , 300, 200)
    maFenetre~create(20, 20, 300, 200, , , "BACKGROUND")
    self~newStaticText(100, 50, 100, 20, "STATIC", "Texte dans la fenêtre")