Titre de style Setext avec un attribut `id` {#idTitre1}
===========================================

**Contents**

[TOC]

## Titre de style atx avec un attribut `id` ## {#idTitre2}

Les barres de soulignement ne génèrent plus d'emphase à l'intérieur d'un mot:

- Le nom du fichier est «mon_fichier_texte.txt».
- Le nom du fichier est «mon__fichier__texte.txt».

Pour les autres contextes, l'emphase est encore générée:

- J'utilise _Markdown Extra_.
- J'utilise __Markdown Extra__.

Voici une liste de définitions:

Mot 1
: définition
Mot 2
: définition

Voici maintenant un bloc de code balisé:

~~~
<em>Code HTML</em> affiché
<strong>sans être interprété</strong>.
~~~

Markdown Extra permet de préciser des abréviations, par exemple:

*[bac]: baccalauréat
*[HTML]: Hypertext Markup Language

Toutes les occurrences de «bac» et «HTML» trouvées dans le texte seront marquées pour permettre l'affichage de la définition lors du passage du curseur.

Voici maintenant une phrase contenant un lien vers une note de bas de page[^1].

Les tableaux sont également supportés:

| Titre de tableau 1 | Titre de tableau 2 |
| ------------------ | ------------------ |
| Cellule            | Cellule            |
| Cellule            | Cellule            |

La note de bas de page créée un peu plus haut peut être définie n'importe où dans le texte, par exemple ici:

[^1]: Voici la note de bas de page.

Enfin, deux nouveaux caractères peuvent être échappés: le deux-points (\:) et la barre verticale (\|).
