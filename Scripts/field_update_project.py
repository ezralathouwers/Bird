"""Add the audio Live Activity target while preserving local signing/settings."""
import hashlib
import re


def uid(name):return hashlib.sha1(('birder-field-20261126:'+name).encode()).hexdigest()[:24].upper()


def object_span(text,key):
    match=re.search(r'\b'+re.escape(key)+r'\b(?:\s*/\*.*?\*/)?\s*=\s*\{',text,re.S)
    if not match:raise ValueError('Projectobject ontbreekt: '+key)
    i=match.end();depth=1;quoted=False
    while i<len(text):
        if text[i]=='\\' and quoted:i+=2;continue
        if text[i]=='"':quoted=not quoted
        if not quoted:
            if text.startswith('/*',i):
                end=text.find('*/',i+2)
                if end<0:raise ValueError('Onvolledige projectcommentaar')
                i=end+2;continue
            if text[i]=='{':depth+=1
            if text[i]=='}':
                depth-=1
                if depth==0:return match.start(),i+1
        i+=1
    raise ValueError('Onvolledig projectobject')


def block(text,key):
    a,b=object_span(text,key);return text[a:b]


def append_array(text,key,field,values):
    a,b=object_span(text,key);part=text[a:b]
    match=re.search(r'\b'+field+r'\s*=\s*\((.*?)\)',part,re.S)
    if not match:raise ValueError('Projectveld ontbreekt: '+field)
    content=match.group(1);extra=[v for v in values if v not in content]
    if not extra:return text
    new=content.rstrip()
    if new and not new.endswith(','):new+=','
    new+=' '+', '.join(extra)+','
    part=part[:match.start(1)]+new+part[match.end(1):]
    return text[:a]+part+text[b:]


def update_project(text):
    app='F75109BEB4DD8800DA6B45F8';project='98F54143AB4E86B28C3AFEE0'
    definitions={}
    def add(name,body):
        key=uid(name);definitions[key]=key+' = { '+body+' };\n';return key
    new_sources=['BirdingCompanion/Models/AudioRecordingAttributes.swift','BirdingCompanion/Features/Identification/AudioRecordingActivity.swift']
    app_build=[];refs=[]
    for path in new_sources:
        ref=add(path,'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "'+path+'"; sourceTree = SOURCE_ROOT;')
        refs.append(ref);app_build.append(add(path+'-app','isa = PBXBuildFile; fileRef = '+ref+';'))
    shared=uid(new_sources[0]);widget=add('widget-file','isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "BirdingAudioActivity/AudioRecordingWidget.swift"; sourceTree = SOURCE_ROOT;');refs.append(widget)
    product=add('extension-product','isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; path = BirderAudioActivity.appex; sourceTree = BUILT_PRODUCTS_DIR;')
    builds=[add('shared-widget','isa = PBXBuildFile; fileRef = '+shared+';'),add('widget-build','isa = PBXBuildFile; fileRef = '+widget+';')]
    sources=add('widget-sources','isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+', '.join(builds)+'); runOnlyForDeploymentPostprocessing = 0;')
    frameworks=add('widget-frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    resources=add('widget-resources','isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    configs=[]
    for name,config in [('Debug','E9B2E96ABC5F6856F2BE79CF'),('Release','5A8C91857F674E16E2724F47')]:
        original=block(text,config)
        identifier=re.search(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([^";]+)"?\s*;',original)
        if not identifier:raise ValueError('Bundle identifier niet gevonden')
        team=re.search(r'DEVELOPMENT_TEAM\s*=\s*"?([^";]+)"?\s*;',original)
        team_setting=' DEVELOPMENT_TEAM = "'+team.group(1).strip()+'";' if team else ''
        build_version=re.search(r'CURRENT_PROJECT_VERSION\s*=\s*"?([^";]+)"?\s*;',original)
        marketing=re.search(r'MARKETING_VERSION\s*=\s*"?([^";]+)"?\s*;',original)
        version=build_version.group(1).strip() if build_version else '1'
        release=marketing.group(1).strip() if marketing else '0.1'
        configs.append(add('widget-config-'+name,'isa = XCBuildConfiguration; name = '+name+'; buildSettings = { SWIFT_VERSION = "6.0"; SWIFT_STRICT_CONCURRENCY = complete; IPHONEOS_DEPLOYMENT_TARGET = "17.0"; TARGETED_DEVICE_FAMILY = 1; SDKROOT = iphoneos; CODE_SIGN_STYLE = Automatic; PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = "'+identifier.group(1).strip()+'.AudioActivity"; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = "BirdingAudioActivity/Info.plist"; CURRENT_PROJECT_VERSION = "'+version+'"; MARKETING_VERSION = "'+release+'"; SKIP_INSTALL = YES; APPLICATION_EXTENSION_API_ONLY = YES; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";'+team_setting+' };'))
    config_list=add('widget-config-list','isa = XCConfigurationList; buildConfigurations = ('+', '.join(configs)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    target=add('widget-target','isa = PBXNativeTarget; name = BirderAudioActivity; productName = BirderAudioActivity; buildConfigurationList = '+config_list+'; buildPhases = ('+', '.join([sources,frameworks,resources])+'); buildRules = (); dependencies = (); productReference = '+product+'; productType = "com.apple.product-type.app-extension";')
    proxy=add('widget-proxy','isa = PBXContainerItemProxy; containerPortal = '+project+'; proxyType = 1; remoteGlobalIDString = '+target+'; remoteInfo = BirderAudioActivity;')
    dependency=add('widget-dependency','isa = PBXTargetDependency; target = '+target+'; targetProxy = '+proxy+';')
    embed=add('widget-embed-build','isa = PBXBuildFile; fileRef = '+product+'; settings = { ATTRIBUTES = (RemoveHeadersOnCopy,); };')
    embed_phase=add('widget-embed-phase','isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ('+embed+'); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;')
    for key,value in definitions.items():
        try:a,b=object_span(text,key)
        except ValueError:
            root=re.search(r'\bobjects\s*=\s*\{',text)
            if not root:raise ValueError('Geen Xcode-objecten gevonden')
            text=text[:root.end()]+'\n'+value+text[root.end():]
        else:
            # Existing target may have been assigned a team in Xcode; preserve it.
            if key in [uid('widget-config-Debug'),uid('widget-config-Release')]:continue
            text=text[:a]+value.rstrip().removesuffix(';')+text[b:]
    text=append_array(text,'949D493B91791558E87BC5D7','files',app_build)
    text=append_array(text,'DC76E9F0C0006E8F919E0C51','children',refs)
    text=append_array(text,'FBDC4F23F93125BBEEAE800C','children',[product])
    text=append_array(text,app,'buildPhases',[embed_phase])
    text=append_array(text,app,'dependencies',[dependency])
    text=append_array(text,project,'targets',[target])
    return text
