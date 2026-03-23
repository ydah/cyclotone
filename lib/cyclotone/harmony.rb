# frozen_string_literal: true

module Cyclotone
  module Harmony
    NOTE_OFFSETS = {
      "c" => 0, "cs" => 1, "db" => 1, "d" => 2, "ds" => 3, "eb" => 3, "e" => 4,
      "f" => 5, "fs" => 6, "gb" => 6, "g" => 7, "gs" => 8, "ab" => 8, "a" => 9,
      "as" => 10, "bb" => 10, "b" => 11
    }.freeze

    SCALES = {
      major: [0, 2, 4, 5, 7, 9, 11],
      minor: [0, 2, 3, 5, 7, 8, 10],
      dorian: [0, 2, 3, 5, 7, 9, 10],
      phrygian: [0, 1, 3, 5, 7, 8, 10],
      lydian: [0, 2, 4, 6, 7, 9, 11],
      mixolydian: [0, 2, 4, 5, 7, 9, 10],
      locrian: [0, 1, 3, 5, 6, 8, 10],
      harmonic_minor: [0, 2, 3, 5, 7, 8, 11],
      melodic_minor: [0, 2, 3, 5, 7, 9, 11],
      whole_tone: [0, 2, 4, 6, 8, 10],
      chromatic: (0..11).to_a,
      pentatonic_major: [0, 2, 4, 7, 9],
      pentatonic_minor: [0, 3, 5, 7, 10],
      blues: [0, 3, 5, 6, 7, 10],
      egyptian: [0, 2, 5, 7, 10],
      hirajoshi: [0, 2, 3, 7, 8],
      iwato: [0, 1, 5, 6, 10],
      enigmatic: [0, 1, 4, 6, 8, 10, 11],
      neapolitan_major: [0, 1, 3, 5, 7, 9, 11],
      neapolitan_minor: [0, 1, 3, 5, 7, 8, 11]
    }.freeze

    CHORDS = {
      major: [0, 4, 7],
      minor: [0, 3, 7],
      diminished: [0, 3, 6],
      augmented: [0, 4, 8],
      sus2: [0, 2, 7],
      sus4: [0, 5, 7],
      major7: [0, 4, 7, 11],
      minor7: [0, 3, 7, 10],
      dominant7: [0, 4, 7, 10]
    }.freeze

    module_function

    def scale(name, pattern, root: 0)
      intervals = SCALES.fetch(name.to_sym)
      root_note = note_number(root)

      Pattern.ensure_pattern(pattern).fmap do |value|
        apply_scale(intervals, root_note, value)
      end
    end

    def chord(name, root: 0)
      root_note = note_number(root)
      notes = CHORDS.fetch(name.to_sym) { raise ArgumentError, "unknown chord #{name}" }.map do |interval|
        root_note + interval
      end

      Pattern.pure(notes)
    end

    def arpeggiate(pattern, mode: :up)
      Pattern.ensure_pattern(pattern).flat_map_events do |event|
        notes = extract_notes(event.value)
        next [event] if notes.empty?

        ordered = order_notes(notes, mode)
        segment_length = event.part.duration / ordered.length

        ordered.each_with_index.map do |note, index|
          part = TimeSpan.new(
            event.part.start + (segment_length * index),
            event.part.start + (segment_length * (index + 1))
          )

          Event.new(whole: part, part: part, value: note)
        end
      end
    end

    def note_number(value)
      return value.to_i if value.is_a?(Numeric)

      normalized = value.to_s.strip.downcase
      match = normalized.match(/\A([a-g](?:s|b)?)(-?\d+)\z/)
      return normalized.to_i if match.nil?

      NOTE_OFFSETS.fetch(match[1]) + ((match[2].to_i + 1) * 12)
    end

    def apply_scale(intervals, root_note, value)
      if value.is_a?(Hash) && value.key?(:note)
        value.merge(note: map_degree(intervals, root_note, value[:note]))
      else
        map_degree(intervals, root_note, value)
      end
    end
    private_class_method :apply_scale

    def map_degree(intervals, root_note, value)
      degree = note_number(value)
      octave, index = degree.divmod(intervals.length)
      root_note + intervals[index] + (octave * 12)
    end
    private_class_method :map_degree

    def extract_notes(value)
      return value[:note] if value.is_a?(Hash) && value[:note].is_a?(Array)
      return value if value.is_a?(Array)

      []
    end
    private_class_method :extract_notes

    def order_notes(notes, mode)
      case mode.to_sym
      when :down
        notes.reverse
      when :updown
        notes + notes[1...-1].reverse
      when :converge
        left = notes.each_slice(2).map(&:first)
        right = notes.each_slice(2).map(&:last).compact.reverse
        left.zip(right).flatten.compact
      else
        notes
      end
    end
    private_class_method :order_notes
  end
end

module Cyclotone
  class Pattern
    def up(semitones)
      fmap do |value|
        if value.is_a?(Hash) && value.key?(:note)
          value.merge(note: value[:note] + semitones.to_i)
        else
          value + semitones.to_i
        end
      end
    end

    def scale(name, root: 0)
      Harmony.scale(name, self, root: root)
    end

    def arp(mode = :up)
      Harmony.arpeggiate(self, mode: mode)
    end

    alias arpeggiate arp
  end
end
