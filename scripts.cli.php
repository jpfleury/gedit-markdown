#!/usr/bin/php
<?php

// ChangeLog vers Markdown
if ($argv[1] == 'mdtxt')
{
	$fichierALire = $argv[2];
	$fic = fopen($fichierALire . '.mdtxt', 'w');
	$fichier = file_get_contents($fichierALire);
	
	$fichier = preg_replace('/^/m', "\t", $fichier);
	$fichier = preg_replace('/^\t=== ([^=]+) ===$/m', '- $1' . "\n", $fichier);
	$fichier = preg_replace('/^\t([0-9]{4}(-[0-9]{2}){2})  /m', "\t" . '- $1&nbsp;&nbsp;', $fichier);
	$fichier = preg_replace('/^\t\t\* (.+)$/m', "\t\t" . '- $1', $fichier);
	$fichier = preg_replace('/,\n\t\t- (?! )/m', ",  \n\t\t", $fichier);
	$fichier = preg_replace('/\.\n\t\t- (?! )/m', ".\n\n\t\t- ", $fichier);
	$fichier = preg_replace('/^\t$/m', '', $fichier);
	
	// Optionnel. Supprime l'adresse courriel.
	$fichier = preg_replace('/^(\t- [0-9]{4}(-[0-9]{2}){2}[^<]+) <[^@]+@[^>]+>/m', '$1', $fichier);
	
	fwrite($fic, $fichier);
	fclose($fic);
}

?>
