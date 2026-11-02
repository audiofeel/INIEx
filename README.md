# INIEx

**INIEx** is a small Windows command-line utility for reading, querying, enumerating and updating INI files. It supports nested section paths and is particularly useful from the **Inno Setup Preprocessor**, where values from an external INI file can be used while the installer is being compiled.

INIEx is independent of FMXBridge and FMXPixie. It can be used in an ordinary Inno Setup project or from any other process that can launch a command-line program.

## Features

- Read values from ordinary and nested sections.
- Check whether sections, subsections and keys exist.
- Enumerate section keys and nested sections.
- Return either direct child sections or all descendants.
- Calculate the total size from values stored in nested sections.
- Update existing INI values and create keys or sections when needed.
- Read UTF-8 INI files and write updated files as UTF-8 without a BOM.
- Optionally write the command result to a text file.

## Repository contents

```text
INIEx/
├── INIEx.dpr                 Delphi source
├── INIEx.dproj               Delphi project
├── INIEx.res                 Project resource
└── Win32/
    └── Release/
        ├── Test.ini          Test data
        ├── _1_*.bat ...      Command-line test scripts
        └── INIEx.exe         Generated here after a Release build
```

The test scripts are kept in `Win32/Release` so they can run next to the executable produced by the current project configuration.

## Build

1. Open `INIEx.dproj` in Delphi.
2. Select the **Win32** platform and **Release** configuration.
3. Build the project.
4. The executable is generated in `Win32\Release\INIEx.exe`.

The project is a console application and uses Delphi RTL units. No FMXBridge, FMXPixie or other third-party package is required by the source shown here.

The checked-in project configuration currently targets Win32. A Win64 build has not been added to this repository configuration.

## Usage

```text
INIEx.exe <Command> [switches] ["/o=C:\path\result.txt"] "C:\path\file.ini"
```

The INI file path is supplied as the final non-switch argument. The `/o` switch is optional; when specified, the command result is also written to that file. The result is still printed to the console.

Switch names and command names are case-insensitive. Section paths accept both `\` and `|` as level separators. For example, `Player1|Stats` and `Player1\Stats` refer to the same nested path.

### Commands

| Command | Required switches | Result |
|---|---|---|
| `IsSectionExists` | `/Sec=<Section>` | `1` if the section exists, otherwise `0` |
| `IsSubSectionExists` | `/MainSec=<Main> /SubSec=<Path>` | `1` if the nested section exists, otherwise `0` |
| `IsValueExists` | `/Sec=<Section> /Key=<Key>` | `1` if the key exists, otherwise `0` |
| `IsSubValueExists` | `/MainSec=<Main> /SubSec=<Path> /Key=<Key>` | `1` if the nested key exists, otherwise `0` |
| `ReadString` | `/Sec=<Section> /Key=<Key>` | Value of the key; empty when it is not found |
| `ReadSubString` | `/MainSec=<Main> /SubSec=<Path> /Key=<Key>` | Value of the nested key; empty when it is not found |
| `GetSectionKeysCount` | `/Sec=<Section>` | Number of keys in the section |
| `GetSectionKey` | `/Sec=<Section> /Idx=<N>` | Key name at the zero-based index |
| `GetSubSectionsCount` | `/MainSec=<Main> [/RootOnly=true]` | Number of child sections or descendants |
| `GetSubSection` | `/MainSec=<Main> /Idx=<N> [/RootOnly=true]` | Child section name at the zero-based index |
| `GetSubSectionKeysCount` | `/MainSec=<Main> /SubSec=<Path>` | Number of keys in the selected nested section |
| `GetSubSectionKey` | `/MainSec=<Main> /SubSec=<Path> /Idx=<N>` | Key name at the zero-based index in the nested section |
| `CalcTotalDiskSizeByte` | `/MainSec=<Main> /Key=<Key>` | Sum of the specified key across descendant sections, in bytes |
| `SetString` | `/Sec=<Section> /Key=<Key> /Value=<Value>` | `1` when the INI file was updated |
| `SetSubString` | `/MainSec=<Main> /SubSec=<Path> /Key=<Key> /Value=<Value>` | `1` when the INI file was updated |

`/RootOnly` defaults to `false`. With `true`, enumeration returns only direct children of the specified section. With `false`, it returns all descendants, with paths relative to `/MainSec`.

`GetSectionKey`, `GetSubSectionKey` and `GetSubSection` use zero-based indexes. An out-of-range index returns an empty string.

### Size values

`CalcTotalDiskSizeByte` parses plain numeric byte values and values with the following suffixes:

- `B` — bytes
- `KB` — kibibytes (1024 bytes)
- `MB` — 1024 KB
- `GB` — 1024 MB
- `TB` — 1024 GB

Hexadecimal values with a `0x` prefix are also accepted. The command searches all descendants of `/MainSec` and adds the values of the requested `/Key` where present.

### Updating an INI file

`SetString` writes a value into the specified section. `SetSubString` addresses a nested section using `/MainSec` and `/SubSec`. If the target section or key does not exist, the writer creates it. Existing comments and unrelated lines are retained by the text-based writer.

The current command-line implementation requires a non-empty `/Value`. Empty values are not supported by `SetString` or `SetSubString` at present. The output file is saved as UTF-8 without a BOM.

Quote a complete switch when its value contains spaces. For example:

```bat
INIEx.exe SetString /Sec=General /Key=Name "/Value=My application" ".\settings.ini"
INIEx.exe ReadString /Sec=General /Key=Name ".\settings.ini"
```

## Examples

### Read a value

```bat
INIEx.exe ReadString /Sec=General /Key=Publisher ".\Test.ini"
```

### Read from a nested section

```bat
INIEx.exe ReadSubString /MainSec=Players /SubSec="Player1|Stats" /Key=Level ".\Test.ini"
```

### Enumerate direct child sections

```bat
INIEx.exe GetSubSectionsCount /MainSec=Players /RootOnly=true ".\Test.ini"
INIEx.exe GetSubSection /MainSec=Players /Idx=0 /RootOnly=true ".\Test.ini"
```

### Calculate the total size

```bat
INIEx.exe CalcTotalDiskSizeByte /MainSec=Datas /Key=Size ".\Test.ini"
```

### Write a value

```bat
INIEx.exe SetSubString /MainSec=Players /SubSec="Player1|Stats" /Key=Level /Value=12 ".\Test.ini"
```

**Note:** write commands modify the supplied INI file. Use a copy when experimenting with important configuration files.

## Inno Setup Preprocessor

INIEx can be called from the Inno Setup Preprocessor with `ExecAndGetFirstLine`. The utility runs during compilation; the compiled installer does not need `INIEx.exe` unless the installer script explicitly includes it as a payload.

A small macro example:

```iss
#define ReadINIEx(Str sFunc, Str sParams) \
  Local[0] = sFunc + " " + sParams + " """ + AddBackSlash(SourcePath) + "settings.ini" + """ , \
  ExecAndGetFirstLine(AddBackSlash(SourcePath) + "INIEx.exe", Local[0], "")

#define AppName ReadINIEx('ReadString', '/Sec=Setup /Key=AppName')
```

The executable path in the macro must point to the location of `INIEx.exe`, and the INI path must point to the configuration file used during compilation.

## Tests

Build the project first so that `Win32\Release\INIEx.exe` exists. Then run the numbered `.bat` files in `Win32\Release`. They use `Test.ini` and print the result of each command.

The write-command tests (`_14_SetString.bat` and `_15_SetSubString.bat`) make temporary copies of `Test.ini` in `%TEMP%`. They do not modify the tracked fixture.

The test scripts are manual command-line checks. They are not an automated CI test suite, and they have not been executed in this environment because the Delphi/Windows executable is not available here.

## Exit codes

| Code | Meaning |
|---:|---|
| `0` | Command completed successfully |
| `1` | No command-line arguments were supplied; short help is printed |
| `2` | An error occurred; the message is printed with the `[error]` prefix |

## License

No license file is currently included. Until a license is chosen and added by the author, do not assume that public availability grants permission to redistribute or modify the source.
