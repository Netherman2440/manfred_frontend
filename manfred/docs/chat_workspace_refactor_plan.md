# Chat Workspace UI Refactor Plan

## Cel

Rozbić obecny monolityczny `chat_workspace_page.dart` na małe, czytelne i reużywalne widgety, tak żeby:

- każda kolumna workspace była osobnym plikiem,
- wspólne prymitywy UI trafiły do `ui/core/`,
- itemy konwersacji zostały uproszczone do dwóch typów: `user` i `agent`,
- `tool` i `delegate` zostały całkowicie usunięte z mocków, modeli, renderingu i testów.

## Aktualny stan

Obecnie cały ekran siedzi w jednym pliku:

- `manfred/lib/ui/screens/chat_workspace_page.dart`

W tym pliku są zmieszane:

- layout desktop/mobile,
- wszystkie 4 kolumny,
- lokalne prymitywy UI (`_PanelShell`, `_HoverSurface`, `_IconButtonCard`, `_OutlineActionButton`),
- itemy konwersacji,
- logika hover,
- elementy raili i prawej kolumny.

Dodatkowo model mocków nadal zakłada 4 typy wpisów:

- `userMessage`
- `assistantMessage`
- `toolCard`
- `delegateThread`

To jest sprzeczne z docelowym uproszczeniem.

## Docelowa struktura katalogów

Proponowany target:

```text
manfred/lib/ui/
  core/
    agent_avatar.dart
    hover_tile_container.dart
    panel_background.dart
  mock/
    manfred_mock_data.dart
  screens/
    chat_workspace/
      chat_workspace_page.dart
      layout/
        desktop_workspace_layout.dart
        mobile_workspace_layout.dart
      columns/
        agent_column.dart
        sessions_column.dart
        conversation_column.dart
        additional_column.dart
      conversation/
        conversation_list.dart
        items/
          user_message_item.dart
          agent_message_item.dart
      sessions/
        session_list_item.dart
      additional/
        highlight_card.dart
        resource_card.dart
      controls/
        workspace_icon_button.dart
        workspace_outline_button.dart
        composer_mock.dart
```

## Zasady architektoniczne

### 1. Strona ma tylko składać layout

`chat_workspace_page.dart` nie powinien zawierać prywatnych widgetów domenowych. Jego rola:

- dobrać mobile vs desktop,
- wstrzyknąć `workspace`,
- złożyć kolumny w jeden layout.

### 2. Każda kolumna to osobny widget

Obowiązkowe pliki:

- `agent_column.dart`
- `sessions_column.dart`
- `conversation_column.dart`
- `additional_column.dart`

Każda z tych klas odpowiada za własny layout wewnętrzny i przyjmuje tylko niezbędne dane wejściowe.

### 3. Powtarzalne UI idzie do `core/`

Na ten moment warto wydzielić:

- `agent_avatar.dart`
  - kołowy avatar/agenta,
  - używany w `agent_column` i w itemach konwersacji.
- `hover_tile_container.dart`
  - wspólny interaktywny prostokąt z hoverem,
  - używany dla itemów sesji i itemów konwersacji,
  - może opcjonalnie obsługiwać `onTap`, `padding`, `borderRadius`, `isActive`.
- `panel_background.dart`
  - opcjonalny wrapper dla tła kolumn,
  - ma sens tylko jeśli chcemy ujednolicić `background`, `radius`, `border`, `shadow`.

Uwaga: `panel_background.dart` nie jest konieczny na siłę. Jeśli okaże się zbyt cienką abstrakcją, można zostawić zwykły `BoxDecoration` lub helper w osobnym pliku stylów. W przeciwieństwie do tego `hover_tile_container.dart` ma wysoką wartość i powinien być wydzielony.

### 4. Uproszczony model konwersacji

Docelowo zostają tylko dwa typy wpisów:

- `user`
- `agent`

To implikuje:

- usunięcie `ConversationEntryType.toolCard`,
- usunięcie `ConversationEntryType.delegateThread`,
- uproszczenie `ConversationEntryMock`,
- usunięcie pól potrzebnych tylko pod tool/delegate:
  - `status`
  - `previewTitle`
  - `previewBody`
  - `tags`
  - `threadCount`

Jeśli część z tych pól ma wrócić później, nie trzymamy ich teraz „na zapas”. Przywrócimy je przy osobnym refaktorze tooli.

## Docelowy podział odpowiedzialności

### `chat_workspace_page.dart`

Odpowiedzialność:

- wybór mobile/desktop,
- osadzenie tła całego ekranu,
- przekazanie danych do layoutów.

Bez:

- itemów list,
- przycisków domenowych,
- widgetów konwersacji,
- widgetów raili.

### `agent_column.dart`

Odpowiedzialność:

- pionowa lista agentów,
- home/new root action,
- stała szerokość kolumny,
- użycie wspólnego `AgentAvatar`.

### `sessions_column.dart`

Odpowiedzialność:

- nagłówek sekcji,
- lista sesji,
- przycisk `New Session`,
- ewentualne przyszłe zwijanie sekcji.

Powinna używać:

- `HoverTileContainer`,
- osobnego `SessionListItem`.

### `conversation_column.dart`

Odpowiedzialność:

- nagłówek aktywnej sesji,
- lista wpisów,
- composer,
- wybór między `UserMessageItem` i `AgentMessageItem`.

Nie renderuje:

- tool cardów,
- delegate cardów.

### `additional_column.dart`

Odpowiedzialność:

- highlights,
- resources,
- przyszłe zwijanie kolumny.

Na razie to nadal będzie kolumna „Artifacts”, ale nazwa pliku i widgetu powinna być neutralna, bo zawartość może się zmieniać.

## Plan wykonania

### Etap 1. Przygotowanie struktury

- przenieść ekran do folderu `screens/chat_workspace/`,
- utworzyć podfoldery `columns/`, `conversation/`, `sessions/`, `additional/`, `controls/`,
- utworzyć `ui/core/` na wspólne prymitywy.

Rezultat:

- czytelny podział katalogów przed przenoszeniem kodu.

### Etap 2. Wydzielenie wspólnych prymitywów

- wydzielić `AgentAvatar`,
- wydzielić `HoverTileContainer`,
- zdecydować, czy `PanelBackground` ma być widgetem czy helperem dekoracji,
- wydzielić wspólne przyciski z obecnych `_IconButtonCard` i `_OutlineActionButton`.

Rezultat:

- kolejne widgety będą budowane już na stabilnych klockach.

### Etap 3. Rozbicie layoutu na kolumny

- wydzielić `AgentColumn`,
- wydzielić `SessionsColumn`,
- wydzielić `ConversationColumn`,
- wydzielić `AdditionalColumn`,
- wydzielić osobno `DesktopWorkspaceLayout` i `MobileWorkspaceLayout`.

Rezultat:

- `chat_workspace_page.dart` staje się małym compositorem.

### Etap 4. Rozbicie wnętrza konwersacji

- wydzielić `conversation_list.dart`,
- wydzielić `user_message_item.dart`,
- wydzielić `agent_message_item.dart`,
- oprzeć oba itemy o wspólny `AgentAvatar` i `HoverTileContainer`.

Rezultat:

- jasny podział na dwa jedyne wspierane typy wiadomości.

### Etap 5. Uproszczenie modeli i mocków

- zmienić `ConversationEntryType` do 2 wartości,
- uprościć `ConversationEntryMock`,
- usunąć tool/delegate z `ManfredMockData.workspace`,
- zaktualizować right rail counts/opisy, jeśli przestaną pasować do nowego stanu.

Rezultat:

- dane są zgodne z nowym UI i nie trzymają martwych struktur.

### Etap 6. Aktualizacja testów

- przepisać `widget_test.dart`,
- usunąć asercje na:
  - `update_theme_tokens`
  - `session-rail-refresh`
- dodać asercje na obecność:
  - 4 kolumn w desktopie,
  - uproszczone itemy konwersacji,
  - brak tool/delegate entry.

Rezultat:

- test pilnuje nowego kontraktu UI zamiast starego mocka.

## Kolejność wdrożenia

Rekomendowana kolejność implementacji:

1. `ui/core/`
2. `controls/`
3. `columns/`
4. `conversation/items/`
5. modele i mocki
6. testy

To minimalizuje przepinanie kodu i zmniejsza ryzyko, że będziemy refaktorować te same fragmenty dwa razy.

## Decyzje projektowe

### `PanelBackground`

Rekomendacja:

- na start zrobić to jako mały widget lub helper dekoracji,
- nie rozbudowywać go o logikę layoutową,
- odpowiada tylko za: `background`, `radius`, `border`, `shadow`.

Powód:

- kolumny różnią się zachowaniem i sizingiem,
- wspólny jest głównie wygląd, nie struktura.

### `HoverTileContainer`

Rekomendacja:

- wydzielić obowiązkowo.

API minimalne:

- `child`
- `padding`
- `onTap`
- `isActive`
- opcjonalnie `borderRadius`

Powód:

- ten sam wzorzec będzie użyty w wielu miejscach,
- obecnie hover jest rozproszony po kilku widgetach i dubluje kod.

### `AgentAvatar`

Rekomendacja:

- jeden wspólny widget dla raila agentów i avatarów w konwersacji,
- różnice obsłużyć parametrami, np. `size`, `label`, `accentColor`, `isActive`.

Powód:

- kołowy avatar to już ustalony wzorzec,
- będzie wielokrotnie używany.

## Ryzyka

- zbyt wczesne wydzielanie cienkich wrapperów może wprowadzić sztuczną architekturę,
- mobile layout może wymagać osobnych uproszczeń zamiast 1:1 kopiowania desktopu,
- po usunięciu `tool/delegate` część obecnych tekstów w prawej kolumnie może przestać mieć sens i trzeba je dopasować razem z mockami.

## Definition of Done

Refaktor uznajemy za zakończony, gdy:

- `chat_workspace_page.dart` nie zawiera lokalnych widgetów domenowych,
- każda z 4 kolumn ma własny plik,
- istnieje `ui/core/` z co najmniej:
  - `agent_avatar.dart`
  - `hover_tile_container.dart`
- konwersacja obsługuje tylko `user` i `agent`,
- `tool` i `delegate` są usunięte z mocków, typów i renderingu,
- test widgetowy przechodzi po nowym kontrakcie UI.

## Proponowany pierwszy commit roboczy

Najbezpieczniejszy pierwszy krok implementacyjny:

- utworzyć nową strukturę folderów,
- przenieść wspólne prymitywy do `ui/core/`,
- wydzielić 4 kolumny bez zmiany zachowania,
- dopiero potem uprościć modele i wyciąć `tool/delegate`.

To rozdziela refaktor strukturalny od refaktoru danych i ułatwia review.
