//=============================================================================
//  MuseScore
//  Music Composition & Notation
//
//  "Straight Up Deltaruning It" Plugin
//
//  Copyright (C) 2025 silvncr
//
//      Based on the
//          Note Names Plugin
//
//      Copyright (C) 2012 Werner Schweer
//      Copyright (C) 2013 - 2021 Joachim Schmitz
//      Copyright (C) 2014 Jörn Eichler
//      Copyright (C) 2020 Johan Temmerman
//
//      Sourced from
//          <https://github.com/musescore/MuseScore/blob/edf6004ecee4d0de89ad0cb7a3f0103efa9d7c42/share/plugins/note_names/notenames.qml>
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 2
//  as published by the Free Software Foundation and appearing in
//  the file LICENCE.GPL
//=============================================================================

import QtQuick 2.2
import MuseScore 3.0

MuseScore {
   version: "4.0"
   description: "Notates your piece to arrange for the DELTARUNE Ch.4 in-game piano"
   title: "Straight Up Deltaruning It"
   categoryCode: "composing-arranging-tools"
   thumbnailName: "StraightUpDeltaruningIt.png"

   // Small note name size is fraction of the full font size.
   property real fontSizeMini: 0.7;
   property int last_case: 95;

   function nameChord (notes, text, small) {
      var sep = "\n";   // change to "," if you want them horizontally (anybody?)
      var oct = "";
      var name;
      for (var i = 0; i < notes.length; i++) {
         if (!notes[i].visible)
            continue // skip invisible notes
         if (text.text) // only if text isn't empty
            text.text = sep + text.text;
         if (small)
            text.fontSize *= fontSizeMini
         if (typeof notes[i].tpc === "undefined") // like for grace notes ?!?
            return

         switch (notes[i].pitch) {
            case last_case: name = "."; break; // same as last
            // B major, B4-B6
            case 71: name = "○\n$O"; last_case = notes[i].pitch; break; // B4
            case 73: name = "⇒\n$E"; last_case = notes[i].pitch; break; // C#5
            case 75: name = "⇘\n$SE"; last_case = notes[i].pitch; break; // D#5
            case 76: name = "⇓\n$S"; last_case = notes[i].pitch; break; // E5
            case 78: name = "⇙\n$SW"; last_case = notes[i].pitch; break; // F#5
            case 80: name = "⇐\n$W"; last_case = notes[i].pitch; break; // G#5
            case 82: name = "⇖\n$NW"; last_case = notes[i].pitch; break; // A#5
            case 83: if (last_case >= 83) {name = "●\nO"} else {name = "⇧\n$N"}; last_case = notes[i].pitch; break; // B5
            case 85: name = "→\nE"; last_case = notes[i].pitch; break; // C#6
            case 87: name = "↘\nSE"; last_case = notes[i].pitch; break; // D#6
            case 88: name = "↓\nS"; last_case = notes[i].pitch; break; // E6
            case 90: name = "↙\nSW"; last_case = notes[i].pitch; break; // F#6
            case 92: name = "←\nW"; last_case = notes[i].pitch; break; // G#6
            case 94: name = "↖\nNW"; last_case = notes[i].pitch; break; // A#6
            case 95: name = "↑\nN"; last_case = notes[i].pitch; break; // B6

            default: name = qsTr("?")   + text.text; break;
         } // end switch tpc

         // octave, middle C being C4
         //oct = (Math.floor(notes[i].pitch / 12) - 1)
         // or
         //oct = (Math.floor(notes[i].ppitch / 12) - 1)
         // or even this, similar to the Helmholtz system but one octave up
         //var octaveTextPostfix = [",,,,,", ",,,,", ",,,", ",,", ",", "", "'", "''", "'''", "''''", "'''''"];
         //oct = octaveTextPostfix[Math.floor(notes[i].pitch / 12)];
         text.text = name + oct + text.text
      }  // end for note
   }

   function renderGraceNoteNames (cursor, list, text, small) {
      if (list.length > 0) {     // Check for existence.
         // Now render grace note's names...
         for (var chordNum = 0; chordNum < list.length; chordNum++) {
            // iterate through all grace chords
            var chord = list[chordNum];
            // Set note text, grace notes are shown a bit smaller
            nameChord(chord.notes, text, small)
            if (text.text)
               cursor.add(text)
            // X position the note name over the grace chord
            text.offsetX = chord.posX
            switch (cursor.voice) {
               case 1: case 3: text.placement = Placement.BELOW; break;
            }

            // If we consume a text we must manufacture a new one.
            if (text.text)
               text = newElement(Element.LYRICS);    // Make another text
         }
      }
      return text
   }

   onRun: {
      curScore.startCmd()

      var cursor = curScore.newCursor();
      var startStaff;
      var endStaff;
      var endTick;
      var fullScore = false;
      cursor.rewind(1);
      if (!cursor.segment) { // no selection
         fullScore = true;
         startStaff = 0; // start with 1st staff
         endStaff  = curScore.nstaves - 1; // and end with last
      } else {
         startStaff = cursor.staffIdx;
         cursor.rewind(2);
         if (cursor.tick === 0) {
            // this happens when the selection includes
            // the last measure of the score.
            // rewind(2) goes behind the last segment (where
            // there's none) and sets tick=0
            endTick = curScore.lastSegment.tick + 1;
         } else {
            endTick = cursor.tick;
         }
         endStaff = cursor.staffIdx;
      }
      console.log(startStaff + " - " + endStaff + " - " + endTick)

      for (var staff = startStaff; staff <= endStaff; staff++) {
         for (var voice = 0; voice < 4; voice++) {
            cursor.rewind(1); // beginning of selection
            cursor.voice    = voice;
            cursor.staffIdx = staff;

            if (fullScore)  // no selection
               cursor.rewind(0); // beginning of score
            while (cursor.segment && (fullScore || cursor.tick < endTick)) {
               if (cursor.element && cursor.element.type === Element.CHORD) {
                  var text = newElement(Element.LYRICS);      // Make a text

                  // First...we need to scan grace notes for existence and break them
                  // into their appropriate lists with the correct ordering of notes.
                  var leadingLifo = Array();   // List for leading grace notes
                  var trailingFifo = Array();  // List for trailing grace notes
                  var graceChords = cursor.element.graceNotes;
                  // Build separate lists of leading and trailing grace note chords.
                  if (graceChords.length > 0) {
                     for (var chordNum = 0; chordNum < graceChords.length; chordNum++) {
                        var noteType = graceChords[chordNum].notes[0].noteType
                        if (noteType === NoteType.GRACE8_AFTER || noteType === NoteType.GRACE16_AFTER ||
                              noteType === NoteType.GRACE32_AFTER) {
                           trailingFifo.unshift(graceChords[chordNum])
                        } else {
                           leadingLifo.push(graceChords[chordNum])
                        }
                     }
                  }

                  // Next process the leading grace notes, should they exist...
                  text = renderGraceNoteNames(cursor, leadingLifo, text, true)

                  // Now handle the note names on the main chord...
                  var notes = cursor.element.notes;
                  nameChord(notes, text, false);
                  if (text.text)
                     cursor.add(text);

                  switch (cursor.voice) {
                     case 1: case 3: text.placement = Placement.BELOW; break;
                  }

                  if (text.text)
                     text = newElement(Element.LYRICS) // Make another text object

                  // Finally process trailing grace notes if they exist...
                  text = renderGraceNoteNames(cursor, trailingFifo, text, true)
               } // end if CHORD
               cursor.next();
            } // end while segment
         } // end for voice
      } // end for staff

      curScore.endCmd()
      quit();
   } // end onRun
}
