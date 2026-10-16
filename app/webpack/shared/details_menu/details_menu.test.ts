import initDetailsMenu from "./details_menu";

function fixture( ): HTMLDetailsElement {
  document.body.innerHTML = `
    <button id="outside">Outside</button>
    <details data-details-menu>
      <summary>Menu</summary>
      <ul><li><a href="/one">One</a></li></ul>
    </details>
  `;
  const details = document.querySelector( "details" ) as HTMLDetailsElement;
  initDetailsMenu( details );
  details.open = true;
  return details;
}

const press = ( target: Element, key: string ) => target.dispatchEvent(
  new KeyboardEvent( "keydown", { key, bubbles: true } )
);

describe( "initDetailsMenu", ( ) => {
  it( "closes when clicking outside the menu", ( ) => {
    const details = fixture( );
    ( document.getElementById( "outside" ) as HTMLElement ).click( );
    expect( details.open ).toBe( false );
  } );

  it( "stays open when clicking inside the menu", ( ) => {
    const details = fixture( );
    ( details.querySelector( "li" ) as HTMLElement ).click( );
    expect( details.open ).toBe( true );
  } );

  it( "closes on Escape and returns focus to the summary", ( ) => {
    const details = fixture( );
    const link = details.querySelector( "a" ) as HTMLElement;
    link.focus( );
    press( link, "Escape" );
    expect( details.open ).toBe( false );
    expect( document.activeElement ).toBe( details.querySelector( "summary" ) );
  } );

  it( "ignores other keys", ( ) => {
    const details = fixture( );
    press( details.querySelector( "a" ) as HTMLElement, "Tab" );
    expect( details.open ).toBe( true );
  } );
} );
