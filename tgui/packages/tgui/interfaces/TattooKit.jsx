import { useBackend } from '../backend';
import {
  Box,
  Button,
  ColorBox,
  Input,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
  Tabs,
  Table
} from 'tgui-core/components';
import { Window } from '../layouts';

export const TattooKit = (props) => {
  const { act, data } = useBackend();
  const {
    target_name,
    ink_uses,
    max_ink_uses,
    ink_color,
    selected_zone,
    selected_name,
    artist_name,
    tattoo_design,
    selected_layer,
    selected_font,
    preview_text,
    body_parts = [],
  } = data;

  return (
    <Window
      title="Professional Tattoo Kit"
      width={900}
      height={700}>
      <Window.Content scrollable>
        {/* TOP SECTION: Selected Area Details */}
        <Section title={`Target: ${target_name || "No Target"}`}>
          <LabeledList>
            <LabeledList.Item label="Selected Area">
              {selected_name || "None"}
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Stack>
                <Stack.Item>
                  <ColorBox color={ink_color || "#000000"} />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="palette"
                    tooltip="Change Ink Color"
                    onClick={() => act('change_color')}
                  />
                </Stack.Item>
              </Stack>
            </LabeledList.Item>
            <LabeledList.Item label="Ink Remaining">
              <ProgressBar
                value={ink_uses || 0}
                minValue={0}
                maxValue={max_ink_uses || 30}
                color={(ink_uses || 0) > 0 ? 'good' : 'bad'}>
                {ink_uses || 0}/{max_ink_uses || 30}
              </ProgressBar>
            </LabeledList.Item>
          </LabeledList>
        </Section>

        {/* DESIGN SECTION: Only shown when area is selected */}
        {selected_zone && (
          <>
            <Section title="Tattoo Design">
              <Stack vertical>
                <Stack.Item>
                  <LabeledList>
                    <LabeledList.Item label="Artist Signature">
                      <Input
                        fluid
                        value={artist_name || ''}
                        placeholder="Enter artist name... Use %s for automatic signature"
                        onChange={(e, value) => act('set_artist', {
                          value: value,
                        })}
                      />
                    </LabeledList.Item>
                    <LabeledList.Item label="Tattoo Description">
                      <Input
                        fluid
                        value={tattoo_design || ''}
                        placeholder="Describe the tattoo design... Use :heart: for emoji"
                        onChange={(e, value) => act('set_design', {
                          value: value,
                        })}
                      />
                    </LabeledList.Item>
                    <LabeledList.Item label="Layer">
                      <Stack>
                        <Stack.Item>
                          <Button
                            selected={selected_layer === 1}
                            onClick={() => act('set_layer', {
                              layer: 1
                            })}>
                            Under
                          </Button>
                        </Stack.Item>
                        <Stack.Item>
                          <Button
                            selected={selected_layer === 2}
                            onClick={() => act('set_layer', {
                              layer: 2
                            })}>
                            Normal
                          </Button>
                        </Stack.Item>
                        <Stack.Item>
                          <Button
                            selected={selected_layer === 3}
                            onClick={() => act('set_layer', {
                              layer: 3
                            })}>
                            Over
                          </Button>
                        </Stack.Item>
                      </Stack>
                    </LabeledList.Item>
                    <LabeledList.Item label="Font">
                      <Tabs>
                        <Tabs.Tab
                          selected={selected_font === "Pen"}
                          onClick={() => act('set_font', {
                            font: "Pen"
                          })}>
                          Pen
                        </Tabs.Tab>
                        <Tabs.Tab
                          selected={selected_font === "Fountain Pen"}
                          onClick={() => act('set_font', {
                            font: "Fountain Pen"
                          })}>
                          Fountain Pen
                        </Tabs.Tab>
                        <Tabs.Tab
                          selected={selected_font === "Crayon"}
                          onClick={() => act('set_font', {
                            font: "Crayon"
                          })}>
                          Crayon
                        </Tabs.Tab>
                        <Tabs.Tab
                          selected={selected_font === "Printer"}
                          onClick={() => act('set_font', {
                            font: "Printer"
                          })}>
                          Printer
                        </Tabs.Tab>
                        <Tabs.Tab
                          selected={selected_font === "Charcoal"}
                          onClick={() => act('set_font', {
                            font: "Charcoal"
                          })}>
                          Charcoal
                        </Tabs.Tab>
                      </Tabs>
                    </LabeledList.Item>
                  </LabeledList>
                </Stack.Item>

                <Stack.Item mt={1}>
                  <Button
                    fluid
                    icon="paint-brush"
                    color="good"
                    disabled={!artist_name || !tattoo_design || ink_uses <= 0}
                    onClick={() => act('apply_tattoo')}>
                    Apply Tattoo to {selected_name}
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>

            {/* PREVIEW SECTION */}
            <Section title="Preview">
              <Box style={{ "min-height": "100px" }}>
                <div dangerouslySetInnerHTML={{ __html: preview_text || "No preview available" }} />
              </Box>
            </Section>
          </>
        )}

        {/* BODY PARTS SELECTION */}
        <Section
          title="Available Body Parts"
          buttons={
            <Button
              icon="fill-drip"
              tooltip="Refill Ink"
              onClick={() => act('refill_ink')}>
              Refill Ink
            </Button>
          }>
          <Table>
            <Table.Row header>
              <Table.Cell>Body Part</Table.Cell>
              <Table.Cell>Status</Table.Cell>
              <Table.Cell>Tattoos</Table.Cell>
              <Table.Cell width="20%">Action</Table.Cell>
            </Table.Row>
            {body_parts.map((part) => (
              <BodyPartRow
                key={part.zone}
                part={part}
                act={act}
                selected_zone={selected_zone}
              />
            ))}
          </Table>
        </Section>
      </Window.Content>
    </Window>
  );
};

const BodyPartRow = (props) => {
  const { part, act, selected_zone } = props;
  const {
    zone,
    name,
    covered,
    current_tattoos,
    max_tattoos,
  } = part;

  // Determine row color based on availability
  let rowColor = "bad"; // Red by default
  if (!covered && current_tattoos < max_tattoos) {
    rowColor = "good"; // Green for available
  } else if (covered) {
    rowColor = "average"; // Orange for covered
  }

  const is_selected = selected_zone === zone;

  return (
    <Table.Row backgroundColor={is_selected ? "blue" : rowColor}>
      <Table.Cell bold={is_selected}>
        {name}
      </Table.Cell>
      <Table.Cell>
        {covered ? "Covered" : "Exposed"}
        {current_tattoos >= max_tattoos && " (Full)"}
      </Table.Cell>
      <Table.Cell>
        {current_tattoos}/{max_tattoos}
      </Table.Cell>
      <Table.Cell>
        <Button
          fluid
          disabled={covered || current_tattoos >= max_tattoos}
          selected={is_selected}
          onClick={() => act('select_zone', { zone: zone })}>
          {is_selected ? "Selected" : "Select"}
        </Button>
      </Table.Cell>
    </Table.Row>
  );
};
