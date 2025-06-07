#include <logger.h>  // Include for logging functionality

// Function to add a potion to the player's inventory
void GetPotion();

/**
 * @brief Event sink responsible for listening to and processing weapon attack logic.
 *
 * Inherits from RE::BSTEventSink<SKSE::ActionEvent>.
 * BSTEventSink is a standard template class (Bethesda Softworks Template) for event listeners.
 * SKSE::ActionEvent is an extended event type provided by SKSE, not native to the original game engine (RE::).
 */
class AttackWeapon :
	public RE::BSTEventSink<SKSE::ActionEvent>
{
public:
	/**
	 * @brief Processes incoming ActionEvent messages from the game.
	 *
	 * This function is overridden from RE::BSTEventSink.
	 * @param a_event Pointer to the ActionEvent data (contains details about the action).
	 * @param a_eventSource The event source broadcasting the event (primarily for listening, not core logic).
	 * @return RE::BSEventNotifyControl::kContinue to allow other listeners to process the event.
	 */
	RE::BSEventNotifyControl ProcessEvent(const SKSE::ActionEvent* a_event, RE::BSTEventSource<SKSE::ActionEvent>* a_eventSource) override
	{
		// Core logic: Determine if the player is swinging a specific Nordic Axe.

		// Defensive check: Ensure the event data itself is valid.
		if (!a_event) {
			return RE::BSEventNotifyControl::kContinue;
		}

		// Defensive check: Ensure the actor performing the action is valid.
		if (!a_event->actor) {
			return RE::BSEventNotifyControl::kContinue;
		}
		auto playerEvent = a_event->actor;  // Actor performing the event

		// Defensive check: Get and validate the player singleton.
		auto player = RE::PlayerCharacter::GetSingleton();
		if (!player) {
			return RE::BSEventNotifyControl::kContinue;
		}

		// Slot check: Determine if the action is from the right-hand slot.
		auto slotEvent = a_event->slot;
		auto rightSlot = SKSE::ActionEvent::Slot::kRight;  // Right-hand slot enumeration

		// Action type check: Determine if the action type is a weapon swing.
		auto actionTypeEvent = a_event->type;
		auto actionType = SKSE::ActionEvent::Type::kWeaponSwing;  // Weapon swing enumeration

		// Defensive check: Ensure the source form (weapon) is valid.
		if (!a_event->sourceForm) {
			return RE::BSEventNotifyControl::kContinue;
		}
		auto weaponSourceForm = a_event->sourceForm->GetFormID();  // Get FormID of the weapon
		auto weaponID = 0x13790;                                   // FormID for the Nordic Axe (example)

		// Main logic: If all conditions match (player, right-hand, weapon swing, specific axe), grant potion.
		if (playerEvent == player) {
			if (slotEvent == rightSlot) {
				if (actionTypeEvent == actionType) {
					if (weaponSourceForm == weaponID) {
						GetPotion();
					}
				}
			}
		}
		return RE::BSEventNotifyControl::kContinue;  // Continue processing the event for other listeners
	}
};

/**
 * @brief Adds a Potion of Minor Healing to the player's inventory.
 * FormID 0x3eadd for Potion of Minor Healing.
 */
void GetPotion()
{
	auto potionOfMinorHealing = RE::TESForm::LookupByID<RE::TESBoundObject>(0x3eadd);
	auto player = RE::PlayerCharacter::GetSingleton();

	// Add 1 potion to the player's container (inventory)
	player->AddObjectToContainer(potionOfMinorHealing, nullptr, 1, nullptr);
}

// Global event listener instance. 'g_' prefix indicates global scope.
static AttackWeapon g_AttackWeaponEventListener;

/**
 * @brief Registers the AttackWeapon event listener with SKSE.
 * This function should be called when the game is fully loaded to ensure event sources are available.
 */
void RegisterEvents()
{
	if (SKSE::GetActionEventSource()) {
		SKSE::GetActionEventSource()->AddEventSink(&g_AttackWeaponEventListener);
	}
}

/**
 * @brief SKSE message callback function.
 * Used to safely register events at the appropriate game loading stage (kPostLoadGame)
 * to prevent issues like listening to non-existent events or CTDs.
 * @param message Pointer to the SKSE message data.
 */
void OnSKSEMessage(SKSE::MessagingInterface::Message* message)
{
	// Check for kPostLoadGame message to ensure events are registered at a safe time.
	if (message->type == SKSE::MessagingInterface::kPostLoadGame) {
		// Prevent double-registration if already registered (though not strictly necessary here).
		RegisterEvents();
	}
}

/**
 * @brief SKSE plugin entry point.
 * This macro handles the initial loading of the plugin by SKSE.
 * It initializes SKSE, sets up logging, and registers the message listener.
 * @param skse Pointer to the SKSE LoadInterface.
 * @return True if plugin loaded successfully, false otherwise.
 */
SKSEPluginLoad(const SKSE::LoadInterface* skse)
{
	SKSE::Init(skse);  // Initialize SKSE
	SetupLog();        // Setup logging
	auto messaging = SKSE::GetMessagingInterface();
	if (messaging) {                                 // Defensive check: Ensure messaging interface is available
		messaging->RegisterListener(OnSKSEMessage);  // Register our message listener
	}
	return true;  // Indicate successful loading
}