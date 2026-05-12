import React, { forwardRef, useRef } from "react";
import type { Meta, StoryObj } from "@storybook/react";
import Carousel from "./carousel";
import type { CarouselProps } from "./carousel";

const meta: Meta<typeof Carousel> = {
  title: "Shared/Carousel",
  component: Carousel
};

export default meta;
type Story = StoryObj<typeof Carousel>;

const PlaceholderItem = forwardRef<HTMLDivElement, { label: string }>(
  ( { label }, ref ) => (
    <div
      ref={ref}
      style={{
        width: 100,
        height: 100,
        background: "#e8f5e9",
        border: "1px solid #74ac00",
        borderRadius: 4,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: 12,
        color: "#444"
      }}
    >
      { label }
    </div>
  )
);

type DemoProps = Omit<CarouselProps, "items" | "itemRef"> & { count?: number };

const CarouselDemo = ( { count = 14, ...props }: DemoProps ) => {
  const itemRef = useRef<HTMLDivElement>( null );

  const items = Array.from( { length: count }, ( _, i ) => (
    <PlaceholderItem key={i} label={`Item ${i + 1}`} ref={i === 0 ? itemRef : undefined} />
  ) );

  return <Carousel {...props} items={items} itemRef={itemRef} />;
};

export const Default: Story = {
  render: ( args ) => <CarouselDemo {...args} />,
  args: {
    title: "Featured Species",
    description: "Species observed in your area this week.",
    url: "/taxa"
  }
};

export const Empty: Story = {
  render: ( args ) => <CarouselDemo {...args} count={0} />,
  args: { title: "Recent Observations", noContent: "No observations found." }
};
