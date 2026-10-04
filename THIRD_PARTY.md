# Произход и лицензи

MIT лицензът в корена важи за авторския код и собствените assets. Следните компоненти запазват оригиналните си условия:

| Компонент | Произход и условия |
|---|---|
| Godot Engine 4.7.2 | [Godot](https://github.com/godotengine/godot/tree/4.7.2-stable), MIT; [лицензи на включените компоненти](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt) |
| OpenXR Vendors 5.1.0 | [Godot XR contributors](https://github.com/GodotVR/godot_openxr_vendors/tree/5.1.0-stable), MIT за собствената част; vendor SDK/loader компонентите имат отделни лицензи в addon-а |
| Meta SDK / loaders | Оригиналните `meta/LICENSE-SDK`, `meta/LICENSE-LOADER` и останалите vendor license файлове се пазят в изтегления addon. Не се прелицензират под MIT на играта. |
| Neucha font | [Google Fonts](https://github.com/google/fonts/tree/main/ofl/neucha), SIL Open Font License 1.1; копие: `assets/Neucha-OFL.txt` |

OpenXR addon-ът се изтегля от официалния release при `setup`; неговите binaries не са включени в Git историята. APK е Godot export с необходимите runtime компоненти; приложими са и техните лицензи.

`assets/characters-r2.png` е оригинален AI-generated atlas, създаден за проекта с ImageGen. Използва се образът на Деснислава; киборгите са процедурни 3D модели от `scripts/enemy_model.gd`. Изходната чужда визуална референция не се разпространява. Собственикът разрешава употреба и модификация на собствените изображения при условията на MIT, доколкото притежава права върху тях.

Звуците и геометрията са генерирани от авторския код. Screenshots в `docs/images/` показват действителния desktop runtime.
