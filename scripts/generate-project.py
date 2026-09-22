#!/usr/bin/env python3
"""Generate a deterministic Xcode project without third-party dependencies."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
objects={}
def ident(label): return hashlib.sha256(label.encode()).hexdigest()[:24].upper()
def add(label, isa, **fields):
    identifier=ident(label); objects[identifier]={'isa':isa, **fields}; return identifier
class Raw(str): pass
def raw(value): return Raw(value)
def render(value):
    if isinstance(value, Raw): return str(value)
    if isinstance(value, str): return '"'+value.replace('\\','\\\\').replace('"','\\"')+'"'
    if isinstance(value, list): return '('+', '.join(render(v) for v in value)+')'
    if isinstance(value, dict): return '{ '+' '.join(f'{render(k)} = {render(v)};' for k,v in value.items())+' }'
    return str(value)
refs={}
files=sorted([p.relative_to(root).as_posix() for p in (root/'WEST').rglob('*.swift')]+['WESTTests/CoreTests.swift','WEST/Resources/Localizable.xcstrings','WEST/Resources/AppIcon.icns','WEST/Resources/Assets.xcassets','Config/Local.xcconfig','Config/App.entitlements','Config/Widget.entitlements','Config/App-Info.plist','Config/Widget-Info.plist'])
for path in files:
    typ='sourcecode.swift' if path.endswith('.swift') else 'text.json.xcstrings' if path.endswith('.xcstrings') else 'folder.assetcatalog' if path.endswith('.xcassets') else 'image.icns' if path.endswith('.icns') else 'text.xcconfig' if path.endswith('.xcconfig') else 'text.plist.xml'
    refs[path]=add('ref:'+path,'PBXFileReference',lastKnownFileType=typ,path=path,sourceTree='SOURCE_ROOT')
products=[]; targets=[]; target_configs={}
for name, product, product_type, paths in [
    ('WEST','WEST time and timer.app','com.apple.product-type.application',[p for p in files if p.endswith('.swift') and not p.startswith(('WEST/Widgets','WESTTests'))]),
    ('WESTWidgets','WESTWidgets.appex','com.apple.product-type.app-extension',[p for p in files if p.endswith('.swift') and p.startswith(('WEST/Shared','WEST/Widgets'))]),
    ('WESTTests','WESTTests.xctest','com.apple.product-type.bundle.unit-test',['WESTTests/CoreTests.swift'])]:
    productref=add('product:'+name,'PBXFileReference',explicitFileType='wrapper.application' if name=='WEST' else 'wrapper.app-extension' if name=='WESTWidgets' else 'wrapper.cfbundle',path=product,sourceTree='BUILT_PRODUCTS_DIR');products.append(raw(productref))
    sourcebuild=[raw(add('build:'+name+':'+p,'PBXBuildFile',fileRef=raw(refs[p]))) for p in paths]
    sources=add('sources:'+name,'PBXSourcesBuildPhase',buildActionMask=2147483647,files=sourcebuild,runOnlyForDeploymentPostprocessing=0)
    frameworks=add('frameworks:'+name,'PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
    res=[] if name=='WESTTests' else [raw(add('resource:'+name,'PBXBuildFile',fileRef=raw(refs['WEST/Resources/Localizable.xcstrings'])))]
    if name == 'WEST': res.append(raw(add('resource:'+name+':assets','PBXBuildFile',fileRef=raw(refs['WEST/Resources/Assets.xcassets']))))
    if name == 'WESTWidgets': res.append(raw(add('resource:'+name+':icon','PBXBuildFile',fileRef=raw(refs['WEST/Resources/AppIcon.icns']))))
    resources=add('resources:'+name,'PBXResourcesBuildPhase',buildActionMask=2147483647,files=res,runOnlyForDeploymentPostprocessing=0)
    settings={'PRODUCT_NAME':'WEST time and timer' if name=='WEST' else name,'PRODUCT_MODULE_NAME':name,'PRODUCT_BUNDLE_IDENTIFIER':'local.westtime.app'+('' if name=='WEST' else '.widgets' if name=='WESTWidgets' else '.tests'), 'SDKROOT':'macosx', 'SUPPORTED_PLATFORMS':'macosx','SWIFT_VERSION':'5.0','MACOSX_DEPLOYMENT_TARGET':'15.0'}
    if name!='WESTTests': settings.update({'INFOPLIST_FILE':'Config/App-Info.plist' if name=='WEST' else 'Config/Widget-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/App.entitlements' if name=='WEST' else 'Config/Widget.entitlements','GENERATE_INFOPLIST_FILE':'NO','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks','@executable_path/../../../../Frameworks']})
    else: settings.update({'GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/WEST time and timer.app/Contents/MacOS/WEST time and timer','BUNDLE_LOADER':'$(TEST_HOST)'})
    if name=='WEST': settings.update({'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS':'NO'})
    if name=='WESTWidgets': settings.update({'APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'$(inherited) WEST_WIDGET_EXTENSION'})
    configs=[]
    for config in ['Debug','Release']:
        confsettings=settings|{'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO'}
        configs.append(raw(add('config:'+name+':'+config,'XCBuildConfiguration',name=config,baseConfigurationReference=raw(refs['Config/Local.xcconfig']),buildSettings=confsettings)))
    conf=add('configs:'+name,'XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
    tid=add('target:'+name,'PBXNativeTarget',name=name,productName=product,productReference=raw(productref),productType=product_type,buildConfigurationList=raw(conf),buildPhases=[raw(sources),raw(frameworks),raw(resources)],buildRules=[],dependencies=[])
    targets.append(raw(tid));target_configs[name]=tid
extensionref=ident('product:WESTWidgets')
embedfile=add('embedfile','PBXBuildFile',fileRef=raw(extensionref),settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']})
embed=add('embed','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[raw(embedfile)],name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0)
objects[target_configs['WEST']]['buildPhases'].append(raw(embed))
for parent, child in [('WEST','WESTWidgets'),('WESTTests','WEST')]:
    proxy=add('proxy:'+parent,'PBXContainerItemProxy',containerPortal=raw(ident('project')),proxyType=1,remoteGlobalIDString=raw(target_configs[child]),remoteInfo=child)
    dep=add('dep:'+parent,'PBXTargetDependency',target=raw(target_configs[child]),targetProxy=raw(proxy))
    objects[target_configs[parent]]['dependencies'].append(raw(dep))
pg=add('products','PBXGroup',children=products,name='Products',sourceTree='<group>')
group=add('main','PBXGroup',children=[raw(r) for r in refs.values()]+[raw(pg)],sourceTree='<group>')
configs=[]
for name in ['Debug','Release']:
    configs.append(raw(add('project-config:'+name,'XCBuildConfiguration',name=name,buildSettings={'CLANG_ENABLE_MODULES':'YES','ENABLE_TESTABILITY':'YES','MACOSX_DEPLOYMENTMENT_TARGET':'15.0'})))
configuration=add('project-configs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
project=add('project','PBXProject',attributes={'LastUpgradeCheck':'1600'},buildConfigurationList=raw(configuration),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','zh-Hans','hi','es','ar','fr','bn','pt','id','ur','ru','Base'],mainGroup=raw(group),productRefGroup=raw(pg),projectDirPath='',projectRoot='',targets=targets)
directory=root/'WEST.xcodeproj';directory.mkdir(exist_ok=True)
text='// !$*UTF8*$!\n'+render({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':raw(project)})+'\n'
(directory/'project.pbxproj').write_text(text)
schemes=directory/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(name):
    product='WEST time and timer.app' if name=='WEST' else 'WESTTests.xctest'
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_configs[name]}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:WEST.xcodeproj"/>'
(schemes/'WEST.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('WEST')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('WESTTests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('WEST')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref('WEST')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Generated WEST.xcodeproj')
