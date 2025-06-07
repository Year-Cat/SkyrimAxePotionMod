# SkyrimAxePotionMod

## 📦 Project Overview

* 🔧 **Plugin Name:** SkyrimAxePotionMod
* 🕹️ **Game Version:** Skyrim Special Edition 1.5.97.0
* 🛠️ **Core Development Library:** [CommonLibSSE-NG](https://github.com/CharmedBaryon/CommonLibSSE-NG)
* 💡 **Development Platform:** C++17 + CMake + Visual Studio 2022
* 📚 **Dependency Management:**
    * Utilizes [vcpkg](https://github.com/microsoft/vcpkg) for C++ dependency management.
    * Integrates [CommonLibSSE-NG](https://github.com/CharmedBaryon/CommonLibSSE-NG) as the primary reverse engineering interface library for Skyrim modding.
    * The project structure is configured based on a CommonLibSSE-NG template, ensuring automatic inclusion of necessary headers, linked libraries, and SKSE plugin build macros.
    * Leverages CMake's integration with vcpkg to ensure a reproducible build environment across different machines.

---

## 📖 Features Overview

This is a straightforward SKSE plugin designed to demonstrate the following core functionalities:

* Automatically adds a potion to the player's inventory when a specific weapon (Iron War Axe) is swung.
* The plugin implements this functionality by listening to `SKSE::ActionEvent` events and incorporates robust defensive programming practices to enhance stability.

---

## ⚙️ Environment Setup & Tool Dependencies

This project utilizes modern C++ build tools and relies on the CommonLibSSE NG framework.

For a **detailed step-by-step guide** on setting up your local development environment, it is highly recommended to refer to this comprehensive Chinese tutorial:
📖 [Plugin Development Environment Setup Tutorial (Chinese)](https://github.com/gottyduke/PluginTutorialCN/blob/master/docs/setup/Setup.md)

---

## 🧰 Installation & Configuration (for End-Users)

1.  This project is designed to be built using a development template that supports `CommonLibSSE-NG`.
2.  Place the compiled `.dll` file into your `Skyrim Special Edition\Data\SKSE\Plugins` directory.
3.  Ensure your game version is **1.5.97.0** and that **SKSE** is correctly installed.

---

## 🪵 Logging Support (`logger.h`)

This project incorporates the [`logger.h`](https://github.com/SkyrimScripting/SKSE_Templates) file for debug logging output. This file adheres to the MIT License, permitting free use and distribution.

---

## 🧠 Project Scope & Learning Objectives

This project serves as an exercise for the author's learning journey in **Reverse Engineering + SKSE Plugin Development + C++ Defensive Design**. The primary focus is not on the mod's specific functionality itself, but rather on:

* Building a stable and reliable event listening framework.
* Understanding pointer stability issues within black-box systems.

---

## 🧾 Acknowledgements & References

* CommonLibSSE-NG by [CharmedBaryon](https://github.com/CharmedBaryon)
* logger.h template by [SkyrimScripting](https://github.com/SkyrimScripting/SKSE_Templates)

---

## 🔓 License

This project is for educational purposes and is licensed under the [MIT License](LICENSE).
