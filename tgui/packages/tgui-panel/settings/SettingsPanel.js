/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { toFixed } from 'common/math';
import { useLocalState } from 'tgui/backend';
import { useDispatch, useSelector } from 'common/redux';
import {
  Box,
  Button,
  ColorBox,
  Divider,
  Dropdown,
  Input,
  LabeledList,
  NumberInput,
  Section,
  Stack,
  Tabs,
  TextArea,
} from 'tgui/components';
import { ChatPageSettings } from '../chat';
import { clearChat, rebuildChat, saveChatToDisk } from '../chat/actions';
import { THEMES } from '../themes';
import {
  changeSettingsTab,
  updateSettings,
  addHighlightSetting,
  removeHighlightSetting,
  updateHighlightSetting,
} from './actions';
import { SETTINGS_TABS, FONTS, MAX_HIGHLIGHT_SETTINGS } from './constants';
import {
  selectActiveTab,
  selectSettings,
  selectHighlightSettings,
  selectHighlightSettingById,
} from './selectors';

export const SettingsPanel = (props, context) => {
  const activeTab = useSelector(context, selectActiveTab);
  const dispatch = useDispatch(context);
  return (
    <Stack fill>
      <Stack.Item>
        <Section fitted fill minHeight="8em">
          <Tabs vertical>
            {SETTINGS_TABS.map((tab) => (
              <Tabs.Tab
                key={tab.id}
                selected={tab.id === activeTab}
                onClick={() =>
                  dispatch(
                    changeSettingsTab({
                      tabId: tab.id,
                    })
                  )
                }
              >
                {tab.name}
              </Tabs.Tab>
            ))}
          </Tabs>
        </Section>
      </Stack.Item>
      <Stack.Item grow basis={0}>
        {activeTab === 'general' && <SettingsGeneral />}
        {activeTab === 'chatPage' && <ChatPageSettings />}
        {activeTab === 'textHighlight' && <TextHighlightSettings />}
      </Stack.Item>
    </Stack>
  );
};

export const SettingsGeneral = (props, context) => {
  const { theme, fontFamily, fontSize, lineHeight } = useSelector(
    context,
    selectSettings
  );
  const dispatch = useDispatch(context);
  const [freeFont, setFreeFont] = useLocalState(context, 'freeFont', false);
  return (
    <Section height="150px">
      <LabeledList>
        <LabeledList.Item label="Тема">
          <Dropdown
            selected={theme}
            options={THEMES}
            onSelected={(value) =>
              dispatch(
                updateSettings({
                  theme: value,
                })
              )
            }
          />
        </LabeledList.Item>
        <LabeledList.Item label="Шрифт">
          <Stack inline align="baseline">
            <Stack.Item>
              {(!freeFont && (
                <Dropdown
                  selected={fontFamily}
                  options={FONTS}
                  onSelected={(value) =>
                    dispatch(
                      updateSettings({
                        fontFamily: value,
                      })
                    )
                  }
                />
              )) || (
                <Input
                  value={fontFamily}
                  onChange={(e, value) =>
                    dispatch(
                      updateSettings({
                        fontFamily: value,
                      })
                    )
                  }
                />
              )}
            </Stack.Item>
            <Stack.Item>
              <Button
                content="Свой шрифт"
                icon={freeFont ? 'lock-open' : 'lock'}
                color={freeFont ? 'good' : 'bad'}
                onClick={() => {
                  setFreeFont(!freeFont);
                }}
              />
            </Stack.Item>
          </Stack>
        </LabeledList.Item>
        <LabeledList.Item label="Размер шрифта">
          <NumberInput
            width="4.2em"
            step={1}
            stepPixelSize={10}
            minValue={8}
            maxValue={32}
            value={fontSize}
            unit="px"
            format={(value) => toFixed(value)}
            onChange={(e, value) =>
              dispatch(
                updateSettings({
                  fontSize: value,
                })
              )
            }
          />
        </LabeledList.Item>
        <LabeledList.Item label="Отступ строк">
          <NumberInput
            width="4.2em"
            step={0.01}
            stepPixelSize={2}
            minValue={0.8}
            maxValue={5}
            value={lineHeight}
            format={(value) => toFixed(value, 2)}
            onDrag={(e, value) =>
              dispatch(
                updateSettings({
                  lineHeight: value,
                })
              )
            }
          />
        </LabeledList.Item>
      </LabeledList>
      <Divider />
      <Stack fill>
        <Stack.Item grow mt={0.15}>
          <Button
            content="Сохранить логи"
            icon="save"
            tooltip="Экспортировать историю текущей вкладки, в виде HTML файла."
            onClick={() => dispatch(saveChatToDisk())}
          />
        </Stack.Item>
        <Stack.Item mt={0.15}>
          <Button.Confirm
            icon="trash"
            confirmContent="Вы уверены?"
            content="Очистить чат"
            tooltip="Очистить историю текущей вкладки."
            onClick={() => dispatch(clearChat())}
          />
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const TextHighlightSettings = (props, context) => {
  const highlightSettings = useSelector(context, selectHighlightSettings);
  const dispatch = useDispatch(context);
  return (
    <Section fill scrollable height="230px">
      <Section>
        <Stack vertical>
          {highlightSettings.map((id, i) => (
            <TextHighlightSetting
              key={i}
              id={id}
              mb={i + 1 === highlightSettings.length ? 0 : '10px'}
            />
          ))}
          {highlightSettings.length < MAX_HIGHLIGHT_SETTINGS && (
            <Stack.Item>
              <Button
                color="transparent"
                icon="plus"
                content="Добавить настройку выделения"
                onClick={() => {
                  dispatch(addHighlightSetting());
                }}
              />
            </Stack.Item>
          )}
        </Stack>
      </Section>
      <Divider />
      <Box>
        <Button icon="check" onClick={() => dispatch(rebuildChat())}>
          Применить
        </Button>
        <Box inline fontSize="0.9em" ml={1} color="label">
          Чат может немного пролагать.
        </Box>
      </Box>
    </Section>
  );
};

const TextHighlightSetting = (props, context) => {
  const { id, ...rest } = props;
  const highlightSettingById = useSelector(context, selectHighlightSettingById);
  const dispatch = useDispatch(context);
  const {
    highlightColor,
    highlightText,
    highlightWholeMessage,
    matchWord,
    matchCase,
  } = highlightSettingById[id];
  return (
    <Stack.Item {...rest}>
      <Stack mb={1} color="label" align="baseline">
        <Stack.Item grow>
          <Button
            content="Удалить"
            color="transparent"
            icon="times"
            onClick={() =>
              dispatch(
                removeHighlightSetting({
                  id: id,
                })
              )
            }
          />
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            content="Регистр"
            tooltip="Если выбран этот параметр, выделение будет чувствительно к регистру."
            checked={matchCase}
            onClick={() =>
              dispatch(
                updateHighlightSetting({
                  id: id,
                  matchCase: !matchCase,
                })
              )
            }
          />
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            checked={highlightWholeMessage}
            content="Целиком"
            tooltip="Если выбрать этот параметр, все сообщение будет выделено жёлтым цветом."
            onClick={() =>
              dispatch(
                updateHighlightSetting({
                  id: id,
                  highlightWholeMessage: !highlightWholeMessage,
                })
              )
            }
          />
        </Stack.Item>
        <Stack.Item shrink={0}>
          <ColorBox mr={1} color={highlightColor} />
          <Input
            width="5em"
            monospace
            placeholder="#ffffff"
            value={highlightColor}
            onInput={(e, value) =>
              dispatch(
                updateHighlightSetting({
                  id: id,
                  highlightColor: value,
                })
              )
            }
          />
        </Stack.Item>
      </Stack>
      <TextArea
        height="3em"
        value={highlightText}
        placeholder="Put terms to highlight here. Separate terms with commas or vertical bars, i.e. (term1 | term2) or (term1, term2). Regex syntax is /[regex]/"
        onChange={(e, value) =>
          dispatch(
            updateHighlightSetting({
              id: id,
              highlightText: value,
            })
          )
        }
      />
    </Stack.Item>
  );
};
