import { Component } from 'react';
import {
  Box,
  Button,
  ColorBox,
  Input,
  KeyListener,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
  Tabs,
  TextArea,
} from 'tgui-core/components';
import { KEY_DOWN, KEY_ENTER, KEY_UP } from 'tgui-core/keycodes';

import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { type BodyZone, BodyZoneSelector } from './common/BodyZoneSelector';

type BodyPart = {
  zone: string;
  name: string;
  type: string;
  covered: boolean;
  current_tattoos: number;
  max_tattoos: number;
};

type TattooKitData = {
  target_name: string;
  ink_uses: number;
  max_uses: number;
  ink_color: string;
  body_parts: BodyPart[];
  selected_zone: BodyZone;
  current_step: string;
};

type TattooKitInnerState = {
  selectedPartIndex: number;
  tattooName: string;
  tattooDesc: string;
  selectedLayer: number;
};

class TattooKitInner extends Component<
  TattooKitData,
  TattooKitInnerState
> {
  state = {
    selectedPartIndex: 0,
    tattooName: '',
    tattooDesc: '',
    selectedLayer: 2, // TATTOO_LAYER_NORMAL
  };

  componentDidMount() {
    this.updateSelectedPartIndexState();
  }

  componentDidUpdate(prevProps: TattooKitData) {
    if (prevProps.selected_zone !== this.props.selected_zone) {
      this.updateSelectedPartIndexState();
    }
  }

  updateSelectedPartIndexState() {
    this.setState({
      selectedPartIndex: this.findSelectedPartAfter(-1) || 0,
    });
  }

  findSelectedPartAfter(after: number): number | undefined {
    const foundIndex = this.props.body_parts.findIndex(
      (part, index) => index > after && !part.covered && part.current_tattoos < part.max_tattoos
    );

    return foundIndex === -1 ? undefined : foundIndex;
  }

  findSelectedPartBefore(before: number): number | undefined {
    for (let index = before; index >= 0; index--) {
      const part = this.props.body_parts[index];
      if (!part.covered && part.current_tattoos < part.max_tattoos) {
        return index;
      }
    }

    return undefined;
  }

  render() {
    const { act } = useBackend<TattooKitData>();
    const { target_name, ink_uses, max_uses, ink_color, body_parts, selected_zone, current_step } = this.props;

    if (current_step === 'design_tattoo') {
      return this.renderDesignStep();
    }

    return this.renderBodyPartSelection();
  }

  renderDesignStep() {
    const { act } = useBackend<TattooKitData>();
    const { selected_zone, ink_color } = this.props;
    const { tattooName, tattooDesc, selectedLayer } = this.state;

    return (
      <Window width={500} height={400} title={`Tattoo Design - ${this.props.target_name}`}>
        <Window.Content>
          <Section title={`Design Tattoo for ${selected_zone}`} fill>
            <Stack vertical fill>
              <Stack.Item>
                <LabeledList>
                  <LabeledList.Item label="Tattoo Name">
                    <Input
                      value={tattooName}
                      width="100%"
                      placeholder="Enter tattoo name..."
                      onChange={(e: any, value: string) => this.setState({ tattooName: value })}
                    />
                  </LabeledList.Item>
                  <LabeledList.Item label="Tattoo Description">
                    <TextArea
                      value={tattooDesc}
                      height="80px"
                      placeholder="Enter tattoo description..."
                      onChange={(e: any, value: string) => this.setState({ tattooDesc: value })}
                    />
                  </LabeledList.Item>
                  <LabeledList.Item label="Ink Color">
                    <Stack>
                      <Stack.Item>
                        <ColorBox color={ink_color} />
                      </Stack.Item>
                      <Stack.Item>
                        <Button
                          icon="palette"
                          onClick={() => act('change_ink_color')}>
                          Change Color
                        </Button>
                      </Stack.Item>
                    </Stack>
                  </LabeledList.Item>
                  <LabeledList.Item label="Tattoo Layer">
                    <Tabs>
                      <Tabs.Tab
                        selected={selectedLayer === 1}
                        onClick={() => this.setState({ selectedLayer: 1 })}>
                        Under Layer
                      </Tabs.Tab>
                      <Tabs.Tab
                        selected={selectedLayer === 2}
                        onClick={() => this.setState({ selectedLayer: 2 })}>
                        Normal Layer
                      </Tabs.Tab>
                      <Tabs.Tab
                        selected={selectedLayer === 3}
                        onClick={() => this.setState({ selectedLayer: 3 })}>
                        Over Layer
                      </Tabs.Tab>
                    </Tabs>
                  </LabeledList.Item>
                </LabeledList>
              </Stack.Item>
              <Stack.Item>
                <Stack>
                  <Stack.Item>
                    <Button
                      icon="arrow-left"
                      onClick={() => act('back_to_selection')}>
                      Back
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="check"
                      color="good"
                      disabled={!tattooName || !tattooDesc}
                      onClick={() => act('design_tattoo', {
                        name: tattooName,
                        desc: tattooDesc,
                        layer: selectedLayer,
                      })}>
                      Apply Tattoo
                    </Button>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </Stack>
          </Section>
        </Window.Content>
      </Window>
    );
  }

  renderBodyPartSelection() {
    const { act } = useBackend<TattooKitData>();
    const { target_name, ink_uses, max_uses, ink_color, body_parts, selected_zone } = this.props;
    const { selectedPartIndex } = this.state;

    return (
      <Window width={600} height={700} title={`Tattoo Kit - ${target_name}`}>
        <Window.Content scrollable>
          <Stack fill vertical>
            <Stack.Item>
              <Section title={`Tattooing: ${target_name}`}>
                <LabeledList>
                  <LabeledList.Item label="Ink Remaining">
                    <ProgressBar
                      value={ink_uses}
                      minValue={0}
                      maxValue={max_uses}
                      color={ink_uses > 0 ? 'good' : 'bad'}>
                      {ink_uses} / {max_uses} uses
                    </ProgressBar>
                  </LabeledList.Item>
                  <LabeledList.Item label="Ink Color">
                    <Stack>
                      <Stack.Item>
                        <ColorBox color={ink_color} />
                      </Stack.Item>
                      <Stack.Item>
                        <Button
                          icon="palette"
                          onClick={() => act('change_ink_color')}>
                          Change Color
                        </Button>
                      </Stack.Item>
                    </Stack>
                  </LabeledList.Item>
                </LabeledList>
              </Section>
            </Stack.Item>

            <Stack.Item grow>
              <Stack fill>
                <Stack.Item width="30%">
                  <BodyZoneSelector
                    onClick={(zone) => act('change_zone', { new_zone: zone })}
                    selectedZone={selected_zone}
                  />
                </Stack.Item>

                <Stack.Item width="70%">
                  <Section title="Available Body Parts" fill scrollable>
                    <Stack vertical>
                      {body_parts.length === 0 && (
                        <Stack.Item>
                          <Box color="bad">No available body parts found!</Box>
                        </Stack.Item>
                      )}
                      {body_parts.map((part, index) => (
                        <Stack.Item key={part.zone}>
                          <Button
                            onClick={() => {
                              act('select_bodypart', {
                                zone: part.zone,
                              });
                            }}
                            disabled={part.covered || part.current_tattoos >= part.max_tattoos || ink_uses <= 0}
                            selected={index === selectedPartIndex}
                            tooltip={
                              part.covered ? "Body part is covered by clothing" :
                              part.current_tattoos >= part.max_tattoos ? "Maximum tattoos reached for this part" :
                              ink_uses <= 0 ? "Out of ink" :
                              "Apply tattoo to this body part"
                            }
                            fluid
                          >
                            <Stack>
                              <Stack.Item grow>
                                {part.name}
                              </Stack.Item>
                              <Stack.Item>
                                <Box color={
                                  part.type === 'bodypart' ? 'good' :
                                  'average'
                                }>
                                  {part.current_tattoos}/{part.max_tattoos}
                                </Box>
                              </Stack.Item>
                              <Stack.Item>
                                <Box color={part.covered ? 'bad' : 'good'}>
                                  {part.covered ? '🔒' : '🔓'}
                                </Box>
                              </Stack.Item>
                            </Stack>
                          </Button>
                        </Stack.Item>
                      ))}
                    </Stack>
                  </Section>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>

          <KeyListener
            onKeyDown={(event) => {
              const keyCode = event.code;
              const part = this.props.body_parts[this.state.selectedPartIndex];

              switch (keyCode) {
                case KEY_DOWN:
                  this.setState((state) => {
                    return {
                      selectedPartIndex:
                        this.findSelectedPartAfter(
                          state.selectedPartIndex,
                        ) ||
                        this.findSelectedPartAfter(-1) ||
                        0,
                    };
                  });

                  break;
                case KEY_UP:
                  this.setState((state) => {
                    return {
                      selectedPartIndex:
                        this.findSelectedPartBefore(
                          state.selectedPartIndex - 1,
                        ) ??
                        this.findSelectedPartBefore(
                          this.props.body_parts.length - 1,
                        ) ??
                        0,
                    };
                  });

                  break;
                case KEY_ENTER:
                  if (part && !part.covered && part.current_tattoos < part.max_tattoos && this.props.ink_uses > 0) {
                    act('select_bodypart', {
                      zone: part.zone,
                    });
                  }

                  break;
              }
            }}
          />
        </Window.Content>
      </Window>
    );
  }
}

export const TattooKit = (props) => {
  const { data } = useBackend<TattooKitData>();

  return (
    <TattooKitInner
      target_name={data.target_name}
      ink_uses={data.ink_uses}
      max_uses={data.max_uses}
      ink_color={data.ink_color}
      body_parts={data.body_parts}
      selected_zone={data.selected_zone}
      current_step={data.current_step}
    />
  );
};
