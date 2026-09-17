import React, {createContext, useContext} from 'react';
import {classic} from './themes/classic';
import type {Theme} from './themes/types';

const ThemeContext = createContext<Theme>(classic);

export const ThemeProvider: React.FC<{theme: Theme; children: React.ReactNode}> = ({
  theme,
  children,
}) => <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>;

export const useTheme = () => useContext(ThemeContext);
