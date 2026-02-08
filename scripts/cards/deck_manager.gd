## DeckManager — Autoload singleton for deck operations.
## Manages draw piles, discard piles, and hand management per character.
extends Node

signal cards_drawn(character: CharacterData, cards: Array[CardData])
signal cards_discarded(character: CharacterData, cards: Array[CardData])
signal deck_shuffled(character: CharacterData)
signal card_added_to_deck(character: CharacterData, card: CardData)
signal card_removed_from_deck(character: CharacterData, card: CardData)

## Per-character draw piles. Dictionary: CharacterData -> Array[CardData]
var draw_piles: Dictionary = {}

## Per-character discard piles. Dictionary: CharacterData -> Array[CardData]
var discard_piles: Dictionary = {}

## Per-character exhaust piles (removed from battle). Dictionary: CharacterData -> Array[CardData]
var exhaust_piles: Dictionary = {}


## Initialize the draw pile for a character from their starting deck.
func initialize_deck(character: CharacterData) -> void:
	var pile: Array[CardData] = []
	for card: CardData in character.starting_deck:
		pile.append(card)
	draw_piles[character] = pile
	discard_piles[character] = [] as Array[CardData]
	exhaust_piles[character] = [] as Array[CardData]
	shuffle_draw_pile(character)


## Initialize decks for all characters at battle start.
func initialize_all_decks(characters: Array[CharacterData]) -> void:
	draw_piles.clear()
	discard_piles.clear()
	exhaust_piles.clear()
	for character: CharacterData in characters:
		initialize_deck(character)


## Draw N cards from a character's draw pile.
func draw_cards(character: CharacterData, count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	var draw_pile: Array[CardData] = draw_piles.get(character, [] as Array[CardData])
	var discard_pile: Array[CardData] = discard_piles.get(character, [] as Array[CardData])

	for i: int in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break  # No more cards available
			# Shuffle discard into draw
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			draw_piles[character] = draw_pile
			discard_piles[character] = discard_pile
			shuffle_draw_pile(character)
			draw_pile = draw_piles[character]

		if not draw_pile.is_empty():
			drawn.append(draw_pile.pop_back())

	cards_drawn.emit(character, drawn)
	return drawn


## Discard a hand of cards for a character.
func discard_hand(character: CharacterData, hand: Array[CardData]) -> void:
	var discard_pile: Array[CardData] = discard_piles.get(character, [] as Array[CardData])
	discard_pile.append_array(hand)
	discard_piles[character] = discard_pile
	cards_discarded.emit(character, hand)


## Discard a single card.
func discard_card(character: CharacterData, card: CardData) -> void:
	var discard_pile: Array[CardData] = discard_piles.get(character, [] as Array[CardData])
	discard_pile.append(card)
	discard_piles[character] = discard_pile


## Exhaust a card (remove from battle entirely).
func exhaust_card(character: CharacterData, card: CardData) -> void:
	var exhaust_pile: Array[CardData] = exhaust_piles.get(character, [] as Array[CardData])
	exhaust_pile.append(card)
	exhaust_piles[character] = exhaust_pile


## Shuffle a character's draw pile.
func shuffle_draw_pile(character: CharacterData) -> void:
	var draw_pile: Array[CardData] = draw_piles.get(character, [] as Array[CardData])
	draw_pile.shuffle()
	draw_piles[character] = draw_pile
	deck_shuffled.emit(character)


## Add a card to a character's permanent deck (for rewards).
func add_card_to_deck(character: CharacterData, card: CardData) -> void:
	character.starting_deck.append(card)
	card_added_to_deck.emit(character, card)


## Remove a card from a character's permanent deck (for shop/events).
func remove_card_from_deck(character: CharacterData, card: CardData) -> void:
	character.starting_deck.erase(card)
	card_removed_from_deck.emit(character, card)


## Get the number of cards remaining in draw pile.
func get_draw_count(character: CharacterData) -> int:
	var pile: Array[CardData] = draw_piles.get(character, [] as Array[CardData])
	return pile.size()


## Get the number of cards in discard pile.
func get_discard_count(character: CharacterData) -> int:
	var pile: Array[CardData] = discard_piles.get(character, [] as Array[CardData])
	return pile.size()
