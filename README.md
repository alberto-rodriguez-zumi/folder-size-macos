# Folder Size

Folder Size is a macOS app that helps you find which files and folders are using disk space. Explore results in a treemap or radial chart, then navigate through them with the directory tree and sortable list.

[Visit the website](https://alberto-rodriguez-zumi.github.io/folder-size-macos/) · [Download the latest release](https://github.com/alberto-rodriguez-zumi/folder-size-macos/releases/latest)

## Requirements and installation

- macOS 15 Sequoia or later.
- 64-bit Mac with Apple Silicon or Intel. The universal build supports both architectures; testing on a range of Macs and macOS versions is ongoing.
- Download the DMG from [Releases](https://github.com/alberto-rodriguez-zumi/folder-size-macos/releases), open it, and drag **Folder Size** to **Applications**.

## Language

Folder Size uses Spanish or Japanese when the system language is one of their variants, and English for other languages. Choose Spanish, English, Japanese, or Automatic in **Folder Size → Settings**; your choice is saved between launches. macOS-provided menus and dialogs may continue to use the system language.

Translations live in `Resources/<language>.lproj/Localizable.strings`. To add a language, include its code in `AppLanguage.supported` and `CFBundleLocalizations`.

## Using Folder Size

1. Open Folder Size. Choose **On demand** (the default, which uses less memory) or **Full**, which keeps more detail in memory. Choose whether to scan hidden folders and how many levels to show in the charts.
2. Select **Choose Folder or Volume** and choose a location. You can cancel a scan. The counter shows items examined, not a completion percentage.
3. Explore the results in treemap or radial view. Hover over an item for details. Open a folder from the chart, directory tree, or list. Use the path bar or back arrow to return to a parent folder.
4. Sort the list by **Name** or **Size**; select the same heading again to reverse the order. The toolbar can show hidden items or hide small folders in the visualization.
5. Select an item to reveal it in Finder, open Terminal, copy its path, or move it to the Trash. The context menu also includes properties and other actions. Moving an item to the Trash requires confirmation and moves the folder's entire contents.

Drag the dividers to resize the directory tree and the bottom list. You can also collapse the tree.

## Permissions and partial results

macOS protects some locations. To grant broader access, enable Folder Size under **System Settings → Privacy & Security → Full Disk Access**, then scan the location again. This does not guarantee access to every location; permissions belonging to other accounts and system restrictions may still apply.

An exclamation mark indicates a partial result. Open **Issues** to see the affected paths and recorded errors. The Full Disk Access prompt is an informational check; if macOS does not allow the app to verify access, the prompt may still appear.

## Understanding the results

Folder sizes are based on allocated file space that the app could scan. Symbolic links are not followed, nested mounted volumes are skipped, and hard links are counted once per scan. Restricted access or changes during a scan can make results incomplete. APFS shared blocks and snapshots may mean deleting an item frees less space than its displayed size.

Recoverable space is an **estimate** based on information provided by macOS, not an exact measurement of purgeable space. Network folders and drives may respond slowly or disconnect. External drives and SMB volumes need further compatibility testing.

## Development

You need Xcode with the macOS SDK and command-line tools. From the repository root:

```sh
bash Scripts/build-preview.sh
bash Scripts/test-chart-layout.sh
bash Scripts/test-results-sort.sh
bash Scripts/test-volume-capacity.sh
bash Scripts/test-full-disk-access.sh
```

The first command creates `Folder-Size-preview.dmg`, a universal ad hoc-signed build for local testing. For a signed and notarized release, see [the release guide](docs/release.md). Product scope and outstanding checks are tracked in [the project plan](docs/plan.md).

## Disclaimer

Folder Size is provided **as is**, without warranties of any kind. Check scan results and selected items before moving anything to the Trash, and keep backups. To the extent permitted by law, the authors are not liable for loss or damage arising from use of the app.
