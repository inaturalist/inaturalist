<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/">
  <xsl:template match="/">
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <link rel="stylesheet" href="http://netdna.bootstrapcdn.com/bootstrap/3.0.0/css/bootstrap.min.css"/>
        <style type="text/css">
          <![CDATA[
            .images {white-space: nowrap; overflow-x:auto; overflow-y:hidden;-webkit-overflow-scrolling: touch;}
            .images .image {display:inline-block; margin-left:1em; max-width:100%;}
            .images img.thumb {max-width:100%; max-height:200px;}
            .images .image:first-child {margin-left:0;}
            .container {padding-top: 1em;padding-bottom: 2em;}
          ]]>
        </style>
      </head>
      <body>
        <div class="container">
          <div id="photos" class="images">
            <xsl:for-each select="//GuidePhoto">
              <div class="image">
                <img src="{href[@type='remote' and @size='small']}" class="thumb img-rounded" data-toggle="modal"/>
                <div class="text-muted text-center">
                  <small>
                    <xsl:text disable-output-escaping="yes"><![CDATA[&copy;]]></xsl:text>
                    <xsl:text disable-output-escaping="yes"><![CDATA[&nbsp;]]></xsl:text>
                    <xsl:value-of select="dcterms:rightsHolder"/>
                  </small>
                </div>
              </div>
            </xsl:for-each>
          </div>
          <h1>
            <xsl:choose>
              <xsl:when test="//displayName">
                <xsl:value-of select="//displayName"/>
                <xsl:if test="//GuideTaxon/name">
                  <div><small><i><xsl:value-of select="//GuideTaxon/name"/></i></small></div>
                </xsl:if>
              </xsl:when>
              <xsl:otherwise>
                <i><xsl:value-of select="//name"/></i>
              </xsl:otherwise>
            </xsl:choose>
          </h1>
          <div id="ranges" class="images">
            <xsl:for-each select="//GuideRange">
              <div class="image">
                <img src="{href[@type='remote' and @size='medium']}" class="thumb img-rounded" data-toggle="modal"/>
                <div class="text-muted text-center">
                  <small>
                    <xsl:text disable-output-escaping="yes"><![CDATA[&copy;]]></xsl:text>
                    <xsl:text disable-output-escaping="yes"><![CDATA[&nbsp;]]></xsl:text>
                    <xsl:value-of select="dcterms:rightsHolder"/>
                  </small>
                </div>
              </div>
            </xsl:for-each>
          </div>
          <xsl:for-each select="//GuideSection">
            <h2><xsl:value-of select="dc:title"/></h2>
            <xsl:value-of select="dc:body" disable-output-escaping="yes"/>
          </xsl:for-each>

          <div class="text-muted">
            <h2>Sources and Attribution</h2>
            <p>
              <small>
                <strong>Photos:</strong>
                <xsl:text disable-output-escaping="yes"><![CDATA[&nbsp;]]></xsl:text>
                <xsl:call-template name="join">
                  <xsl:with-param name="list" select="//GuidePhoto/attribution[text()]" />
                  <xsl:with-param name="separator" select="', '" />
                </xsl:call-template>
              </small>
            </p>
            <p>
              <small>
                <strong>Maps:</strong>
                <xsl:text disable-output-escaping="yes"><![CDATA[&nbsp;]]></xsl:text>
                <xsl:call-template name="join">
                  <xsl:with-param name="list" select="//GuideRange/attribution[text()]" />
                  <xsl:with-param name="separator" select="', '" />
                </xsl:call-template>
              </small>
            </p>
            <p>
              <small>
                <strong>Text: </strong>
                <xsl:for-each select="//GuideSection">
                  <xsl:text disable-output-escaping="yes"><![CDATA[&ldquo;]]></xsl:text>
                  <xsl:value-of select="dc:title"/>
                  <xsl:text disable-output-escaping="yes"><![CDATA[&rdquo;]]></xsl:text>
                  <xsl:text disable-output-escaping="yes"><![CDATA[&nbsp;]]></xsl:text>
                  <xsl:value-of select="attribution[text()]"/>
                  <xsl:if test="position() != last()">
                    <xsl:value-of select="', '" />
                  </xsl:if>
                </xsl:for-each>
              </small>
            </p>
          </div>
        </div>
      </body>
    </html>
  </xsl:template>
  <!-- http://stackoverflow.com/a/798572/720268 -->
  <xsl:template name="join">
    <xsl:param name="list" />
    <xsl:param name="separator"/>
    <xsl:for-each select="$list">
      <xsl:value-of select="." />
      <xsl:if test="position() != last()">
        <xsl:value-of select="$separator"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
